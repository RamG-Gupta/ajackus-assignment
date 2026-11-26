require "net/http"
require "json"

module Billetto
  class Client
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class RequestError < Error; end
    class TemporaryFailure < RequestError; end
    class InvalidResponse < Error; end

    PAGE_SIZE = 30
    MAX_PAGES = 10_000

    def initialize(api_keypair: ENV["BILLETTO_API_KEYPAIR"], base_url: ENV.fetch("BILLETTO_API_URL", "https://api.billetto.com"))
      @api_keypair = api_keypair
      @base_url = base_url
    end

    def fetch_public_events
      each_public_event_page.flat_map(&:itself)
    end

    def each_public_event_page
      return enum_for(__method__) unless block_given?

      raise ConfigurationError, "BILLETTO_API_KEYPAIR is required" if api_keypair.blank?

      page = 1
      loop do
        batch = fetch_page(page)
        yield batch
        break if batch.length < PAGE_SIZE
        raise TemporaryFailure, "Billetto pagination exceeded #{MAX_PAGES} pages" if page >= MAX_PAGES

        page += 1
      end
    end

    private

    attr_reader :api_keypair, :base_url

    def fetch_page(page)
      uri = URI.join(base_url.end_with?("/") ? base_url : "#{base_url}/", "events")
      uri.query = URI.encode_www_form(per_page: PAGE_SIZE, page: page)
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
      rows = json.is_a?(Array) ? json : json["events"] || json["data"]
      raise InvalidResponse, "Expected an event array in Billetto response" unless rows.is_a?(Array)

      rows
    rescue JSON::ParserError, TypeError => e
      raise InvalidResponse, "Billetto returned invalid JSON: #{e.message}"
    rescue SocketError, Timeout::Error, Errno::ECONNRESET, Errno::ECONNREFUSED, IOError, EOFError,
           OpenSSL::SSL::SSLError, Net::HTTPBadResponse => e
      raise TemporaryFailure, "Billetto request failed: #{e.class}"
    end
  end
end
