class EventVote < ApplicationRecord
  belongs_to :event

  validates :clerk_user_id, presence: true
  validates :value, inclusion: { in: %w[up down] }
end
