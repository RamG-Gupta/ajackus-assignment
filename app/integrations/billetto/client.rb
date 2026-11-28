require "net/http"
require "json"

module Billetto
  class Client
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class RequestError < Error; end
    class TemporaryFailure < RequestError; end
    class InvalidResponse < Error; end

    MAX_EVENTS = 100

    def initialize(api_keypair: ENV["BILLETTO_API_KEYPAIR"], base_url: ENV.fetch("BILLETTO_API_URL", "https://billetto.dk/api/v3/public/events"))
      @api_keypair = api_keypair
      @base_url = base_url
    end

    def fetch_public_events
      each_public_event_page.flat_map(&:itself)
    end

    def each_public_event_page
      return enum_for(__method__) unless block_given?

      raise ConfigurationError, "BILLETTO_API_KEYPAIR is required" if api_keypair.blank?

      yield fetch_events
    end

    private

    attr_reader :api_keypair, :base_url

    def fetch_events
      uri = URI(base_url)
      uri.query = URI.encode_www_form(limit: MAX_EVENTS)
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/json"
      request["Api-Keypair"] = api_keypair

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 15) do |http|
        http.request(request)
      end
      unless response.is_a?(Net::HTTPSuccess)
        error_class = response.code.to_i == 429 || response.code.to_i >= 500 ? TemporaryFailure : RequestError
        raise error_class, "Billetto returned HTTP #{response.code}"
      end

      json = JSON.parse(response.body)
      rows = event_rows(json)
      raise InvalidResponse, "Expected an event array in Billetto response" unless rows.is_a?(Array)

      rows
    rescue JSON::ParserError, TypeError => e
      raise InvalidResponse, "Billetto returned invalid JSON: #{e.message}"
    rescue SocketError, Timeout::Error, Errno::ECONNRESET, Errno::ECONNREFUSED, IOError, EOFError,
           OpenSSL::SSL::SSLError, Net::HTTPBadResponse => e
      raise TemporaryFailure, "Billetto request failed: #{e.class}"
    end

    def event_rows(json)
      return json if json.is_a?(Array)
      return unless json.is_a?(Hash)

      %w[events results data].each do |key|
        value = json[key]
        return value if value.is_a?(Array)
        next unless value.is_a?(Hash)

        nested = value["events"] || value["results"]
        return nested if nested.is_a?(Array)
      end
      nil
    end
  end
end
