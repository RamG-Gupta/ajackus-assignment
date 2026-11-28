module Events
  class VoteService
    VALID_VALUES = %w[up down remove].freeze

    def initialize(event_store: Rails.configuration.event_store)
      @event_store = event_store
    end

    def call(command)
      raise ArgumentError, "value must be up, down, or remove" unless VALID_VALUES.include?(command.value)
      raise ArgumentError, "clerk user ID is required" if command.clerk_user_id.blank?

      event = Event.find(command.event_id)
      event.with_lock do
        current = EventVote.find_by(event_id: event.id, clerk_user_id: command.clerk_user_id)
        return current if current&.value == command.value
        return nil if command.value == "remove" && current.nil?

        fact = build_fact(event, command)
        event_store.publish(fact, stream_name: "Event$#{event.id}", expected_version: :auto)
        event_store.link(fact.event_id, stream_name: "User$#{command.clerk_user_id}")
        EventVote.find_by(event_id: event.id, clerk_user_id: command.clerk_user_id)
      end
    end

    private

    attr_reader :event_store

    def build_fact(event, command)
      data = { event_id: event.id, clerk_user_id: command.clerk_user_id }
      case command.value
      when "up" then Upvoted.strict(data: data.merge(value: "up"))
      when "down" then Downvoted.strict(data: data.merge(value: "down"))
      when "remove" then VoteRemoved.strict(data: data)
      end
    end
  end
end
