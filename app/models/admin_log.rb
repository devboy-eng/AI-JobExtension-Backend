class AdminLog < ApplicationRecord
  belongs_to :admin_user, optional: true
  belongs_to :target, polymorphic: true, optional: true
  
  validates :action, presence: true
  validates :details, presence: true
  validates :ip_address, presence: true, format: { with: /\A(?:[0-9]{1,3}\.){3}[0-9]{1,3}\z/ }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_admin, ->(admin_id) { where(admin_user_id: admin_id) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }
  scope :security_events, -> { where(action: SECURITY_ACTIONS) }
  
  SECURITY_ACTIONS = %w[
    login logout failed_login account_locked password_reset
    permission_changed role_assigned suspicious_activity
  ].freeze
  
  USER_ACTIONS = %w[
    user_created user_updated user_deleted user_suspended user_activated
    plan_changed subscription_updated payment_processed refund_issued
  ].freeze
  
  SYSTEM_ACTIONS = %w[
    role_created role_updated role_deleted permission_assigned
    setting_changed system_backup database_update
  ].freeze
  
  def self.log_activity(admin_user, action, details, target = nil, additional_data = {})
    create!(
      admin_user: admin_user,
      action: action.to_s,
      details: details.to_s,
      target: target,
      ip_address: Current.ip_address || '127.0.0.1',
      user_agent: Current.user_agent,
      additional_data: additional_data.to_json
    )
  rescue => e
    Rails.logger.error "Failed to create admin log: #{e.message}"
  end
  
  def self.security_summary(days = 7)
    start_date = days.days.ago.beginning_of_day
    logs = where(created_at: start_date..Time.current)
    
    {
      total_events: logs.count,
      security_events: logs.security_events.count,
      user_actions: logs.where(action: USER_ACTIONS).count,
      system_actions: logs.where(action: SYSTEM_ACTIONS).count,
      failed_logins: logs.where(action: 'failed_login').count,
      suspicious_activities: logs.where(action: 'suspicious_activity').count,
      unique_admins: logs.distinct.count(:admin_user_id)
    }
  end
  
  def parsed_additional_data
    return {} if additional_data.blank?
    JSON.parse(additional_data)
  rescue JSON::ParserError
    {}
  end
  
  def formatted_created_at
    created_at.strftime('%Y-%m-%d %H:%M:%S')
  end
  
  def admin_name
    admin_user&.full_name || 'System'
  end
  
  def is_security_event?
    SECURITY_ACTIONS.include?(action)
  end
  
  def severity
    case action
    when 'failed_login', 'account_locked', 'suspicious_activity'
      'high'
    when 'login', 'logout', 'permission_changed', 'role_assigned'
      'medium'
    else
      'low'
    end
  end
end