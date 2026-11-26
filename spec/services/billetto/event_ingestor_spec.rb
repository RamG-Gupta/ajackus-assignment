require "rails_helper"

RSpec.describe Billetto::EventIngestor do
  let(:client) do
    instance_double(Billetto::Client).tap do |adapter|
      allow(adapter).to receive(:each_public_event_page) { |&block| block.call(records) }
    end
  end
  let(:records) do
    [ { "id" => "external-1", "name" => "A show", "start_date" => "2030-06-01T18:00:00Z", "description" => "Live music" } ]
  end

  subject(:ingestor) { described_class.new(client: client) }

  it "ingests events and updates an existing external event on subsequent syncs" do
    expect { ingestor.call }.to change(Event, :count).by(1)
    allow(client).to receive(:each_public_event_page) do |&block|
      block.call([ { "id" => "external-1", "name" => "Updated show", "start_date" => "2030-06-02T18:00:00Z" } ])
    end
    expect { ingestor.call }.not_to change(Event, :count)
    expect(Event.find_by!(external_id: "external-1").title).to eq("Updated show")
  end

  it "rejects an invalid upstream event before writing any rows" do
    allow(client).to receive(:each_public_event_page) { |&block| block.call([ { "id" => "missing-title" } ]) }
    expect { ingestor.call }.to raise_error(described_class::InvalidEvent)
    expect(Event.count).to eq(0)
  end
end
