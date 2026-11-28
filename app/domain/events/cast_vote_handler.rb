module Events
  class CastVoteHandler
    def initialize(event_store: Rails.configuration.event_store)
      @event_store = event_store
    end

    def call(command)
      VoteService.new(event_store: event_store).call(command)
    end

    private

    attr_reader :event_store
  end
end
