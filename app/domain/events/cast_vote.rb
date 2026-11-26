module Events
  class CastVote
    attr_reader :event_id, :clerk_user_id, :value

    def initialize(event_id:, clerk_user_id:, value:)
      @event_id = Integer(event_id)
      @clerk_user_id = clerk_user_id
      @value = value
    end
  end
end
