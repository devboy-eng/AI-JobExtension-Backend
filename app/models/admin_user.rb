class AdminUser < ApplicationRecord
  has_secure_password
  
  has_many :admin_logs, dependent: :destroy
  has_many :user_logs, dependent: :destroy
  belongs_to :role
  
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }
  validates :first_name, :last_name, presence: true
  validates :status, inclusion: { in: %w[active inactive suspended] }
  
  enum status: { active: 0, inactive: 1, suspended: 2 }
  
  before_create :set_default_status
  after_create :log_creation
  
  scope :active, -> { where(status: :active) }
  scope :by_role, ->(role_name) { joins(:role).where(roles: { name: role_name }) }
  
  def full_name
    "#{first_name} #{last_name}".strip
  end
  
  def can?(permission, resource = nil)
    return false unless active?
    role&.has_permission?(permission, resource)
  end
  
  def log_activity(action, details, target = nil)
    admin_logs.create!(
      action: action,
      details: details,
      target_type: target&.class&.name,
      target_id: target&.id,
      ip_address: Current.ip_address,
      user_agent: Current.user_agent
    )
  end
  
  def last_login_at
    admin_logs.where(action: 'login').maximum(:created_at)
  end
  
  def login_count
    admin_logs.where(action: 'login').count
  end
  
  private
  
  def set_default_status
    self.status ||= :active
  end
  
  def log_creation
    log_activity('account_created', "Admin account created: #{email}")
  end
end