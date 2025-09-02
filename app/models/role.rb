class Role < ApplicationRecord
  has_many :admin_users, dependent: :restrict_with_error
  has_many :role_permissions, dependent: :destroy
  has_many :permissions, through: :role_permissions
  
  validates :name, presence: true, uniqueness: true
  validates :description, presence: true
  validates :color, presence: true, format: { with: /\A#[0-9a-f]{6}\z/i }
  validates :priority, presence: true, uniqueness: true
  
  scope :ordered, -> { order(:priority) }
  scope :active, -> { where(active: true) }
  
  before_validation :normalize_name
  after_create :log_creation
  after_update :log_update
  
  def has_permission?(permission_name, resource = nil)
    return false unless active?
    
    permission = permissions.find_by(name: permission_name)
    return false unless permission
    
    role_permission = role_permissions.find_by(permission: permission)
    return false unless role_permission&.granted?
    
    # Check resource-specific permissions if needed
    if resource && role_permission.conditions.present?
      evaluate_conditions(role_permission.conditions, resource)
    else
      true
    end
  end
  
  def grant_permission(permission_name, granted: true, conditions: nil)
    permission = Permission.find_by(name: permission_name)
    return false unless permission
    
    role_permission = role_permissions.find_or_initialize_by(permission: permission)
    role_permission.granted = granted
    role_permission.conditions = conditions if conditions
    role_permission.save
  end
  
  def revoke_permission(permission_name)
    grant_permission(permission_name, granted: false)
  end
  
  def permission_summary
    {
      total: permissions.count,
      granted: role_permissions.where(granted: true).count,
      denied: role_permissions.where(granted: false).count
    }
  end
  
  private
  
  def normalize_name
    self.name = name&.strip&.titleize
  end
  
  def evaluate_conditions(conditions, resource)
    # Simple condition evaluation - can be extended
    return true if conditions.blank?
    
    begin
      # Parse JSON conditions and evaluate against resource
      parsed_conditions = JSON.parse(conditions)
      parsed_conditions.all? do |key, value|
        resource.respond_to?(key) && resource.send(key) == value
      end
    rescue JSON::ParserError
      false
    end
  end
  
  def log_creation
    AdminLog.create!(
      admin_user: Current.admin_user,
      action: 'role_created',
      details: "Role created: #{name}",
      target_type: self.class.name,
      target_id: id
    )
  end
  
  def log_update
    AdminLog.create!(
      admin_user: Current.admin_user,
      action: 'role_updated', 
      details: "Role updated: #{name}",
      target_type: self.class.name,
      target_id: id
    )
  end
end