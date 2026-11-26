module Billetto
  class EventIngestor
    class InvalidEvent < StandardError; end

    def initialize(client: Client.new)
      @client = client
    end

    def call
      imported = 0
      client.each_public_event_page do |records|
        normalized = records.map { |record| normalize(record) }
        unless normalized.empty?
          Event.transaction do
            Event.upsert_all(
              normalized,
              unique_by: :index_events_on_external_id,
              record_timestamps: true
            )
          end
        end
        imported += normalized.length
      end
      imported
    end

    private

    attr_reader :client

    def normalize(record)
      raise InvalidEvent, "Event payload must be an object" unless record.is_a?(Hash)

      data = record.with_indifferent_access
      external_id = data[:id] || data[:event_id]
      title = data[:title] || data[:name]
      starts_at = data[:starts_at] || data[:start_at] || data[:start_date]
      raise InvalidEvent, "Event is missing an ID, title, or start time" if [ external_id, title, starts_at ].any?(&:blank?)

      parsed_start = Time.zone.parse(starts_at.to_s)
      parsed_end = parse_time(data[:ends_at] || data[:end_at] || data[:end_date])
      raise InvalidEvent, "Event has an invalid date" unless parsed_start
      raise InvalidEvent, "Event end time must be after start time" if parsed_end && parsed_end <= parsed_start

      {
        external_id: external_id.to_s,
        title: title.to_s,
        description: data[:description] || data[:summary],
        starts_at: parsed_start,
        ends_at: parsed_end,
        image_url: image_url(data)
      }
    rescue ArgumentError, TypeError
      raise InvalidEvent, "Event has an invalid date"
    end

    def parse_time(value)
      Time.zone.parse(value.to_s) if value.present?
    end

    def image_url(data)
      image = data[:image]
      image.is_a?(Hash) ? (data[:image_url] || image[:url] || image["url"]) : data[:image_url] || image
    end
  end
end
