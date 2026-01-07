class ApplicationController < ActionController::API
  include ActionController::Cookies
  
  before_action :authenticate_user!, except: [:create, :login, :health]
  
  def health
    render json: { status: 'ok', timestamp: Time.current }
  end
  
  private
  
  def authenticate_user!
    token = request.headers['Authorization']&.split(' ')&.last
    return render json: { error: 'Unauthorized' }, status: :unauthorized unless token
    
    begin
      decoded_token = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: 'HS256')
      @current_user = User.find(decoded_token[0]['user_id'])
    rescue JWT::DecodeError, ActiveRecord::RecordNotFound
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end
  
  def current_user
    @current_user
  end
  
  def generate_token(user)
    JWT.encode({ user_id: user.id, exp: 24.hours.from_now.to_i }, Rails.application.secret_key_base, 'HS256')
  end

  def render_success(data = {})
    render json: { success: true, data: data }, status: :ok
  end

  def render_error(message, status = :bad_request)
    render json: { success: false, error: message }, status: status
  end
end