require "rails_helper"

RSpec.describe "Event votes", type: :request do
  let!(:event) { Event.create!(external_id: "evt-1", title: "Event", starts_at: 1.day.from_now) }

  it "rejects a vote without an authenticated Clerk session" do
    post event_vote_path(event), params: { value: "up" }, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it "renders events and their vote totals for HTML and JSON clients" do
    EventVote.create!(event: event, clerk_user_id: "user_111", value: "up")

    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Event", "Upvotes: 1", "Downvotes: 0")

    get events_path(format: :json)
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).first.fetch("votes")).to eq("up" => 1, "down" => 0)
  end

  it "explains how to populate the event list when no events have synced" do
    Event.delete_all
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No events synced yet", "BILLETTO_API_KEYPAIR", "bin/rails events:sync")
  end

  it "accepts a verified Clerk session and records its subject on the vote" do
    rsa = OpenSSL::PKey::RSA.generate(2048)
    original = ENV.to_hash.slice("CLERK_JWT_KEY", "CLERK_ISSUER", "CLERK_AUTHORIZED_PARTIES")
    ENV["CLERK_JWT_KEY"] = rsa.public_key.to_pem
    ENV["CLERK_ISSUER"] = "https://test.clerk.accounts.dev"
    ENV["CLERK_AUTHORIZED_PARTIES"] = "http://example.com"
    token = JWT.encode(
      { sub: "user_456", iss: ENV.fetch("CLERK_ISSUER"), azp: "http://example.com", exp: 10.minutes.from_now.to_i },
      rsa,
      "RS256"
    )

    post event_vote_path(event), params: { value: "up" }, headers: { "Authorization" => "Bearer #{token}" }, as: :json

    expect(response).to have_http_status(:created)
    expect(EventVote.find_by!(event: event).clerk_user_id).to eq("user_456")
  ensure
    %w[CLERK_JWT_KEY CLERK_ISSUER CLERK_AUTHORIZED_PARTIES].each { |name| ENV.delete(name) }
    original&.each { |name, value| ENV[name] = value }
  end

  it "rejects a signed Clerk token without an expiration" do
    rsa = OpenSSL::PKey::RSA.generate(2048)
    original = ENV.to_hash.slice("CLERK_JWT_KEY", "CLERK_ISSUER", "CLERK_AUTHORIZED_PARTIES")
    ENV["CLERK_JWT_KEY"] = rsa.public_key.to_pem
    ENV["CLERK_ISSUER"] = "https://test.clerk.accounts.dev"
    ENV["CLERK_AUTHORIZED_PARTIES"] = "http://example.com"
    token = JWT.encode(
      { sub: "user_789", iss: ENV.fetch("CLERK_ISSUER"), azp: "http://example.com" },
      rsa,
      "RS256"
    )

    post event_vote_path(event), params: { value: "up" }, headers: { "Authorization" => "Bearer #{token}" }, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(EventVote.where(event: event)).to be_empty
  ensure
    %w[CLERK_JWT_KEY CLERK_ISSUER CLERK_AUTHORIZED_PARTIES].each { |name| ENV.delete(name) }
    original&.each { |name, value| ENV[name] = value }
  end
end
