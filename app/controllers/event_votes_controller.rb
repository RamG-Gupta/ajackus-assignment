class EventVotesController < ApplicationController
  before_action :authenticate_clerk_user!

  def create
    cast_vote(params.require(:value))
  end

  def destroy
    cast_vote("remove")
  end

  private

  def cast_vote(value)
    command = Events::CastVote.new(
      event_id: params[:event_id],
      clerk_user_id: current_clerk_user_id,
      value: value
    )
    Rails.configuration.command_bus.call(command)
    event = Event.find(params[:event_id])
    render json: { votes: event.reload.vote_counts }, status: :ok
  rescue ArgumentError
    render json: { error: "value must be up, down, or remove" }, status: :unprocessable_entity
  end
end
