class Event < ApplicationRecord
  has_many :event_votes, dependent: :delete_all

  validates :external_id, presence: true, uniqueness: true
  validates :title, presence: true
  validates :starts_at, presence: true
  validates :ends_at, comparison: { greater_than: :starts_at }, allow_nil: true

  def vote_counts
    event_votes.group(:value).count
  end
end
