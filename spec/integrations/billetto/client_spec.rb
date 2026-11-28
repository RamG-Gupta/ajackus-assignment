require "rails_helper"

RSpec.describe Billetto::Client do
  it "sends the key pair header and parses a public event page" do
    client = described_class.new(api_keypair: "pair-secret", base_url: "https://billetto.test/api/v3/public/events")
    response = double(code: "200", body: { events: [ { id: "event-1" } ] }.to_json)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    http = double
    allow(http).to receive(:request) do |request|
      expect(request["Api-Keypair"]).to eq("pair-secret")
      expect(request.path).to eq("/api/v3/public/events?limit=100")
      response
    end
    allow(Net::HTTP).to receive(:start).and_yield(http)

    expect(client.fetch_public_events).to eq([ { "id" => "event-1" } ])
  end

  it "raises a typed error when Billetto returns a failed status" do
    client = described_class.new(api_keypair: "pair-secret", base_url: "https://billetto.test/api/v3/public/events")
    response = Net::HTTPBadRequest.new("1.1", "401", "Unauthorized")
    http = double(request: response)
    allow(Net::HTTP).to receive(:start).and_yield(http)

    expect { client.fetch_public_events }.to raise_error(Billetto::Client::RequestError, /HTTP 401/)
  end

  it "requests at most the documented maximum and accepts the public-event response shape" do
    client = described_class.new(api_keypair: "pair-secret", base_url: "https://billetto.test/api/v3/public/events")
    response = double(code: "200", body: { data: { events: [ { id: "event-1", title: "Public event", startdate: "2030-01-01T12:00:00Z" } ] } }.to_json)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    http = double
    allow(http).to receive(:request) do |request|
      expect(URI.decode_www_form(URI(request.path).query).to_h).to eq("limit" => "100")
      response
    end
    allow(Net::HTTP).to receive(:start).and_yield(http)

    expect(client.fetch_public_events.first.fetch("startdate")).to eq("2030-01-01T12:00:00Z")
  end

  it "fails before making a request when credentials are absent" do
    client = described_class.new(api_keypair: nil)
    expect(Net::HTTP).not_to receive(:start)
    expect { client.fetch_public_events }.to raise_error(Billetto::Client::ConfigurationError)
  end
end
