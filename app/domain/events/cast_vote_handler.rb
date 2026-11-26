module Events
  class CastVoteHandler
    def initialize(event_store: Rails.configuration.event_store)
      @event_store = event_store
    end

    def call(command)
      raise ArgumentError, "value must be up or down" unless %w[up down].include?(command.value)
      raise ArgumentError, "clerk user ID is required" if command.clerk_user_id.blank?

      event = Event.find(command.event_id)
      fact_class = command.value == "up" ? Upvoted : Downvoted
      event.with_lock do
        fact = fact_class.strict(data: {
          event_id: event.id,
          clerk_user_id: command.clerk_user_id,
          value: command.value
        })
        event_store.publish(fact, stream_name: "Event$#{event.id}")
        event_store.link(fact.event_id, stream_name: "User$#{command.clerk_user_id}")
      end
    end

    private

    attr_reader :event_store
  end
end
