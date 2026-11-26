class EventsController < ApplicationController
  def index
    events = Event.order(:starts_at).limit(100)
    counts = EventVote.where(event_id: events.map(&:id)).group(:event_id, :value).count
    payload = events.map { |event|
      {
        id: event.id,
        title: event.title,
        description: event.description,
        starts_at: event.starts_at,
        ends_at: event.ends_at,
        image_url: event.image_url,
        votes: {
          up: counts.fetch([ event.id, "up" ], 0),
          down: counts.fetch([ event.id, "down" ], 0)
        }
      }
    }
    respond_to do |format|
      format.html do
        @events = events
        @vote_counts = counts
      end
      format.json { render json: payload }
    end
  end
end
