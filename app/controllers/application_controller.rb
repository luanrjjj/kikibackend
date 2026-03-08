class ApplicationController < ActionController::API
  before_action :authenticate_user!
  skip_before_action :authenticate_user!, if: -> { self.class == SessionsController }


  def current_user
    @current_user
  end

  private

  def authenticate_user!
    token = request.headers['Authorization']&.split(' ')&.last
    if token
      session = Session.find_by(token: token)
      if session && session.expires_at > Time.now
        @current_user = session.user
      else
        render json: { error: 'Invalid or expired token' }, status: :unauthorized
      end
    else
      render json: { error: 'Missing token' }, status: :unauthorized
    end
  end
end