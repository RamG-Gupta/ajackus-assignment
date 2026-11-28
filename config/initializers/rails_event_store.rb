require "arkency/command_bus"

Rails.application.config.to_prepare do
  event_store = RailsEventStore::JSONClient.new
  Events.subscriptions.each do |handler, event_classes|
    event_store.subscribe(handler, to: event_classes)
  end
  Rails.configuration.event_store = event_store

  command_bus = Arkency::CommandBus.new
  command_bus.register(Events::CastVote, ->(command) {
    Events::CastVoteHandler.new(event_store: event_store).call(command)
  })
  Rails.configuration.command_bus = command_bus
end
