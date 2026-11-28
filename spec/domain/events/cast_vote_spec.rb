require "rails_helper"

RSpec.describe Events::CastVote do
  let(:event) { Event.create!(external_id: "evt-1", title: "Event", starts_at: 1.day.from_now) }

  it "persists a domain fact and projects the user's latest vote" do
    Rails.configuration.command_bus.call(described_class.new(event_id: event.id, clerk_user_id: "user_123", value: "up"))
    Rails.configuration.command_bus.call(described_class.new(event_id: event.id, clerk_user_id: "user_123", value: "down"))

    expect(EventVote.find_by!(event: event, clerk_user_id: "user_123").value).to eq("down")
    expect(event.reload.vote_counts).to eq("down" => 1)
    facts = Rails.configuration.event_store.read.stream("Event$#{event.id}").to_a
    expect(facts.map(&:event_type)).to include("Events::Upvoted", "Events::Downvoted")
    user_facts = Rails.configuration.event_store.read.stream("User$user_123").to_a
    expect(user_facts.length).to eq(2)
  end

  it "rejects votes outside the supported values" do
    expect do
      Rails.configuration.command_bus.call(described_class.new(event_id: event.id, clerk_user_id: "user_123", value: "maybe"))
    end.to raise_error(ArgumentError)
  end

  it "keeps repeated votes idempotent, switches a vote, and supports removal" do
    vote = ->(value) { Rails.configuration.command_bus.call(described_class.new(event_id: event.id, clerk_user_id: "user_repeat", value: value)) }

    vote.call("up")
    expect { vote.call("up") }.not_to change { Rails.configuration.event_store.read.stream("Event$#{event.id}").count }
    vote.call("down")
    expect(event.reload.vote_counts).to eq("down" => 1)
    vote.call("remove")
    expect(event.reload.vote_counts).to eq({})
    expect { vote.call("remove") }.not_to change { Rails.configuration.event_store.read.stream("Event$#{event.id}").count }
    expect(Rails.configuration.event_store.read.stream("Event$#{event.id}").map(&:event_type)).to include("Events::VoteRemoved")
  end
end
