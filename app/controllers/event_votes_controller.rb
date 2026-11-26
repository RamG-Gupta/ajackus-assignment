class EventVotesController < ApplicationController
  before_action :authenticate_clerk_user!

  def create
    command = Events::CastVote.new(
      event_id: params[:event_id],
      clerk_user_id: current_clerk_user_id,
      value: params.require(:value)
    )
    Rails.configuration.command_bus.call(command)
    event = Event.find(params[:event_id])
    render json: { votes: event.reload.vote_counts }, status: :created
  rescue ArgumentError
    render json: { error: "value must be up or down" }, status: :unprocessable_entity
  end
end
