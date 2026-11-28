module Events
  class ApplyVote
    def self.call(fact)
      if fact.is_a?(VoteRemoved)
        EventVote.where(event_id: fact.data.fetch(:event_id), clerk_user_id: fact.data.fetch(:clerk_user_id)).delete_all
        return
      end

      vote = EventVote.find_or_initialize_by(
        event_id: fact.data.fetch(:event_id),
        clerk_user_id: fact.data.fetch(:clerk_user_id)
      )
      vote.value = fact.data.fetch(:value)
      vote.save!
    end
  end
end
