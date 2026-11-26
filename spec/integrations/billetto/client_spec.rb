require "rails_helper"

RSpec.describe Billetto::Client do
  it "sends the key pair header and parses a public event page" do
    client = described_class.new(api_keypair: "pair-secret", base_url: "https://billetto.test")
    response = double(code: "200", body: { events: [ { id: "event-1" } ] }.to_json)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    http = double
    allow(http).to receive(:request) do |request|
      expect(request["Api-Keypair"]).to eq("pair-secret")
      expect(request.path).to eq("/events?per_page=30&page=1")
      response
    end
    allow(Net::HTTP).to receive(:start).and_yield(http)

    expect(client.fetch_public_events).to eq([ { "id" => "event-1" } ])
  end

  it "raises a typed error when Billetto returns a failed status" do
    client = described_class.new(api_keypair: "pair-secret", base_url: "https://billetto.test")
    response = Net::HTTPBadRequest.new("1.1", "401", "Unauthorized")
    http = double(request: response)
    allow(Net::HTTP).to receive(:start).and_yield(http)

    expect { client.fetch_public_events }.to raise_error(Billetto::Client::RequestError, /HTTP 401/)
  end

  it "continues across pages until the final partial page" do
    client = described_class.new(api_keypair: "pair-secret", base_url: "https://billetto.test")
    responses = [ Array.new(30) { |index| { id: index } }, [ { id: 31 } ] ].map do |events|
      response = double(code: "200", body: { events: events }.to_json)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      response
    end
    requests = []
    http = double
    allow(http).to receive(:request) do |request|
      requests << request
      responses.shift
    end
    allow(Net::HTTP).to receive(:start).and_yield(http)

    expect(client.fetch_public_events.length).to eq(31)
    expect(requests.map { |request| URI.decode_www_form(URI(request.path).query).to_h.fetch("page") }).to eq(%w[1 2])
  end

  it "fails before making a request when credentials are absent" do
    client = described_class.new(api_keypair: nil)
    expect(Net::HTTP).not_to receive(:start)
    expect { client.fetch_public_events }.to raise_error(Billetto::Client::ConfigurationError)
  end
end
