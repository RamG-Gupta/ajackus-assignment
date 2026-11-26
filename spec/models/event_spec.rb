require "rails_helper"

RSpec.describe Event, type: :model do
  subject(:event) { described_class.new(external_id: "billetto-1", title: "Concert", starts_at: 1.day.from_now) }

  it "requires an external ID, title, and start time" do
    expect(described_class.new).not_to be_valid
    expect(event).to be_valid
  end

  it "rejects an end time before the start time" do
    event.ends_at = event.starts_at - 1.hour
    expect(event).not_to be_valid
  end

  it "handles an end time when the start time is missing" do
    event.starts_at = nil
    event.ends_at = 2.days.from_now
    expect(event).not_to be_valid
  end

  it "enforces external ID uniqueness" do
    event.save!
    duplicate = described_class.new(external_id: event.external_id, title: "Other", starts_at: 1.day.from_now)
    expect(duplicate).not_to be_valid
  end
end
