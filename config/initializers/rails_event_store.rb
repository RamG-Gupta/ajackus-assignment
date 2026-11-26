require "arkency/command_bus"

Rails.application.config.to_prepare do
  event_store = RailsEventStore::JSONClient.new
  event_store.subscribe(Events::ApplyVote, to: [ Events::Upvoted, Events::Downvoted ])
  Rails.configuration.event_store = event_store

  command_bus = Arkency::CommandBus.new
  command_bus.register(Events::CastVote, ->(command) {
    Events::CastVoteHandler.new(event_store: event_store).call(command)
  })
  Rails.configuration.command_bus = command_bus
end
