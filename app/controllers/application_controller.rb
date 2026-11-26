class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def authenticate_clerk_user!
    token = request.authorization&.delete_prefix("Bearer ") || cookies["__session"]
    raise Clerk::SessionVerifier::InvalidToken, "Missing session token" if token.blank?

    @current_clerk_user_id = Clerk::SessionVerifier.call(token)
  rescue Clerk::SessionVerifier::InvalidToken
    render json: { error: "authentication required" }, status: :unauthorized
  end

  attr_reader :current_clerk_user_id
end
