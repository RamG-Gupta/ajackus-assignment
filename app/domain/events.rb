module Events
  def self.subscriptions
    { ApplyVote => [ Upvoted, Downvoted, VoteRemoved ] }
  end
end
