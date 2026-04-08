class ApplicationController < ActionController::API
  before_action :authenticate_user!
  skip_before_action :authenticate_user!, if: -> { self.class == SessionsController }


  def current_user
    @current_user
  end

  private

  def authenticate_admin!
    token = request.headers['Authorization']&.split(' ')&.last
    verification = User.verify_admin_token(token)

    if verification == :unauthorized
      render json: { error: 'Unauthorized' }, status: :unauthorized
    elsif verification == :forbidden
      render json: { error: 'Forbidden' }, status: :forbidden
    end
  end

  def authenticate_subscription
    unless current_user&.subscribed?
      render json: { error: 'Active subscription required' }, status: :method_not_allowed
    end
  end

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