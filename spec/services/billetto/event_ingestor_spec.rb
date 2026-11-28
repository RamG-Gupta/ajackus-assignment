require "rails_helper"

RSpec.describe Billetto::EventIngestor do
  let(:client) do
    instance_double(Billetto::Client).tap do |adapter|
      allow(adapter).to receive(:each_public_event_page) { |&block| block.call(records) }
    end
  end
  let(:records) do
    [ { "id" => "external-1", "title" => "A show", "startdate" => "2030-06-01T18:00:00Z", "image_link" => "https://img.test/show.jpg", "description" => "Live music" } ]
  end

  subject(:ingestor) { described_class.new(client: client) }

  it "ingests events and updates an existing external event on subsequent syncs" do
    expect { ingestor.call }.to change(Event, :count).by(1)
    expect(Event.find_by!(external_id: "external-1").image_url).to eq("https://img.test/show.jpg")
    allow(client).to receive(:each_public_event_page) do |&block|
      block.call([ { "id" => "external-1", "title" => "Updated show", "startdate" => "2030-06-02T18:00:00Z" } ])
    end
    expect { ingestor.call }.not_to change(Event, :count)
    expect(Event.find_by!(external_id: "external-1").title).to eq("Updated show")
  end

  it "skips invalid upstream events without failing the rest of the import" do
    allow(client).to receive(:each_public_event_page) { |&block| block.call([ { "id" => "missing-title" } ]) }
    expect { ingestor.call }.not_to raise_error
    expect(Event.count).to eq(0)
  end
end
