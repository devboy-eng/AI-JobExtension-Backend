class Admin::BaseController < ApplicationController
  before_action :authenticate_admin_user!
  before_action :set_current_admin
  before_action :verify_admin_permissions
  
  protected
  
  def authenticate_admin_user!
    token = extract_token
    return render_unauthorized unless token
    
    begin
      decoded_token = JWT.decode(token, Rails.application.credentials.secret_key_base)[0]
      @current_admin_user = AdminUser.find_by(id: decoded_token['admin_user_id'])
      
      unless @current_admin_user&.active?
        AdminLog.log_activity(@current_admin_user, 'unauthorized_access_attempt', 
                             'Inactive admin attempted access')
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
  
  def verify_admin_permissions
    required_permission = self.class.required_permission
    return true unless required_permission
    
    unless current_admin_user.can?(required_permission)
      AdminLog.log_activity(current_admin_user, 'permission_denied',
                           "Access denied to #{required_permission}")
      render json: { error: 'Insufficient permissions' }, status: :forbidden
      return false
    end
    
    true
  end
  
  def self.required_permission(permission = nil)
    if permission
      @required_permission = permission
    else
      @required_permission
    end
  end
  
  def log_admin_activity(action, details, target = nil)
    AdminLog.log_activity(current_admin_user, action, details, target)
  end
  
  def log_user_activity(user, action, details)
    UserLog.log_user_activity(user, action, details, current_admin_user)
  end
  
  private
  
  def set_current_admin
    Current.admin_user = current_admin_user if current_admin_user
    Current.set_from_request(request)
  end
  
  def extract_token
    header = request.headers['Authorization']
    return nil unless header&.starts_with?('Bearer ')
    header.split(' ').last
  end
  
  def render_unauthorized
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end
  
  def paginate(collection, per_page: 20)
    page = params[:page].to_i
    page = 1 if page < 1
    per_page = params[:per_page].to_i if params[:per_page].present?
    per_page = 20 if per_page < 1 || per_page > 100
    
    offset = (page - 1) * per_page
    paginated = collection.offset(offset).limit(per_page)
    total = collection.count
    
    {
      data: paginated,
      pagination: {
        current_page: page,
        per_page: per_page,
        total_pages: (total.to_f / per_page).ceil,
        total_count: total,
        has_next_page: (page * per_page) < total,
        has_prev_page: page > 1
      }
    }
  end
  
  def success_response(data = {}, message = nil)
    response = { success: true }
    response[:message] = message if message
    response[:data] = data if data.any?
    render json: response
  end
  
  def error_response(message, status = :unprocessable_entity, details = nil)
    response = { success: false, error: message }
    response[:details] = details if details
    render json: response, status: status
  end
end