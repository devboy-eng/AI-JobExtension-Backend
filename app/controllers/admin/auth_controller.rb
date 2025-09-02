class Admin::AuthController < ApplicationController
  def login
    admin_user = AdminUser.find_by(email: params[:email])
    
    if admin_user&.authenticate(params[:password])
      if admin_user.active?
        token = generate_admin_token(admin_user)
        
        AdminLog.log_activity(admin_user, 'login', 
                             "Admin logged in from #{request.remote_ip}")
        
        render json: {
          success: true,
          admin_user: admin_user_response(admin_user),
          token: token
        }
      else
        AdminLog.log_activity(admin_user, 'login_denied', 
                             "Inactive admin attempted login: #{params[:email]}")
        render json: { error: 'Account is inactive' }, status: :unauthorized
      end
    else
      AdminLog.log_activity(nil, 'failed_login', 
                           "Failed admin login attempt: #{params[:email]} from #{request.remote_ip}")
      render json: { error: 'Invalid credentials' }, status: :unauthorized
    end
  end
  
  def logout
    Current.set_from_request(request)
    
    token = extract_token
    if token
      begin
        decoded_token = JWT.decode(token, Rails.application.credentials.secret_key_base)[0]
        admin_user = AdminUser.find_by(id: decoded_token['admin_user_id'])
        
        AdminLog.log_activity(admin_user, 'logout', 
                             "Admin logged out from #{request.remote_ip}") if admin_user
      rescue JWT::DecodeError
        # Token was invalid, still allow logout
      end
    end
    
    render json: { success: true, message: 'Logged out successfully' }
  end
  
  def me
    authenticate_admin_user!
    render json: {
      success: true,
      admin_user: admin_user_response(current_admin_user)
    }
  end
  
  def change_password
    authenticate_admin_user!
    
    unless current_admin_user.authenticate(params[:current_password])
      return render json: { error: 'Current password is incorrect' }, status: :unprocessable_entity
    end
    
    if current_admin_user.update(password: params[:new_password])
      AdminLog.log_activity(current_admin_user, 'password_changed', 
                           'Admin changed password')
      render json: { success: true, message: 'Password updated successfully' }
    else
      render json: { 
        error: 'Password update failed', 
        details: current_admin_user.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end
  
  private
  
  def authenticate_admin_user!
    token = extract_token
    return render_unauthorized unless token
    
    begin
      decoded_token = JWT.decode(token, Rails.application.credentials.secret_key_base)[0]
      @current_admin_user = AdminUser.find_by(id: decoded_token['admin_user_id'])
      
      unless @current_admin_user&.active?
        return render_unauthorized
      end
      
      Current.admin_user = @current_admin_user
      
    rescue JWT::ExpiredSignature
      render json: { error: 'Token expired' }, status: :unauthorized
    rescue JWT::DecodeError, ActiveRecord::RecordNotFound
      render json: { error: 'Invalid token' }, status: :unauthorized
    end
  end
  
  def current_admin_user
    @current_admin_user
  end
  
  def generate_admin_token(admin_user)
    payload = {
      admin_user_id: admin_user.id,
      exp: 24.hours.from_now.to_i
    }
    JWT.encode(payload, Rails.application.credentials.secret_key_base)
  end
  
  def admin_user_response(admin_user)
    {
      id: admin_user.id,
      email: admin_user.email,
      first_name: admin_user.first_name,
      last_name: admin_user.last_name,
      full_name: admin_user.full_name,
      role: {
        id: admin_user.role.id,
        name: admin_user.role.name,
        color: admin_user.role.color
      },
      status: admin_user.status,
      last_login_at: admin_user.last_login_at,
      login_count: admin_user.login_count,
      created_at: admin_user.created_at
    }
  end
  
  def extract_token
    header = request.headers['Authorization']
    return nil unless header&.starts_with?('Bearer ')
    header.split(' ').last
  end
  
  def render_unauthorized
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end
end