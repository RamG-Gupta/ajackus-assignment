namespace :events do
  desc "Fetch and upsert public events from Billetto"
  task sync: :environment do
    count = Billetto::EventIngestor.new.call
    puts "Synchronized #{count} Billetto events"
  end
end
