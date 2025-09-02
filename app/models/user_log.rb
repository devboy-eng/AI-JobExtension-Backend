class UserLog < ApplicationRecord
  belongs_to :user
  belongs_to :admin_user, optional: true
  
  validates :action, presence: true
  validates :details, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }
  scope :plan_changes, -> { where(action: 'plan_changed') }
  scope :admin_remarks, -> { where(action: 'admin_remark') }
  
  PLAN_ACTIONS = %w[
    plan_changed subscription_started subscription_cancelled 
    subscription_renewed payment_failed refund_processed
  ].freeze
  
  ACCOUNT_ACTIONS = %w[
    account_created status_updated profile_updated email_changed
    password_changed login_activity account_suspended account_activated
  ].freeze
  
  AUTOMATION_ACTIONS = %w[
    automation_created automation_updated automation_deleted
    automation_paused automation_resumed dm_sent contact_added
  ].freeze
  
  def self.log_user_activity(user, action, details, admin_user = nil, additional_data = {})
    create!(
      user: user,
      admin_user: admin_user,
      action: action.to_s,
      details: details.to_s,
      ip_address: Current.ip_address,
      user_agent: Current.user_agent,
      additional_data: additional_data.to_json
    )
  rescue => e
    Rails.logger.error "Failed to create user log: #{e.message}"
  end
  
  def self.plan_change_summary(user_id = nil, days = 30)
    logs = plan_changes
    logs = logs.where(user_id: user_id) if user_id.present?
    logs = logs.where(created_at: days.days.ago..Time.current)
    
    {
      total_changes: logs.count,
      upgrades: logs.where("details ILIKE ?", "%upgraded%").count,
      downgrades: logs.where("details ILIKE ?", "%downgraded%").count,
      cancellations: logs.where("details ILIKE ?", "%cancelled%").count,
      recent_changes: logs.limit(10).pluck(:user_id, :details, :created_at)
    }
  end
  
  def parsed_additional_data
    return {} if additional_data.blank?
    JSON.parse(additional_data)
  rescue JSON::ParserError
    {}
  end
  
  def formatted_created_at
    created_at.strftime('%Y-%m-%d %H:%M:%S %Z')
  end
  
  def admin_name
    admin_user&.full_name || 'System'
  end
  
  def is_plan_related?
    PLAN_ACTIONS.include?(action)
  end
  
  def is_admin_action?
    admin_user.present?
  end
  
  def category
    case action
    when *PLAN_ACTIONS
      'subscription'
    when *ACCOUNT_ACTIONS
      'account'
    when *AUTOMATION_ACTIONS
      'automation'
    when 'admin_remark'
      'admin_note'
    else
      'general'
    end
  end
end