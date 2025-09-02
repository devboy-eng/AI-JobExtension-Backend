class RolePermission < ApplicationRecord
  belongs_to :role
  belongs_to :permission
  
  validates :role_id, uniqueness: { scope: :permission_id }
  validates :granted, inclusion: { in: [true, false] }
  
  scope :granted, -> { where(granted: true) }
  scope :denied, -> { where(granted: false) }
  
  after_create :log_creation
  after_update :log_update
  
  def status
    granted? ? 'granted' : 'denied'
  end
  
  private
  
  def log_creation
    AdminLog.create!(
      admin_user: Current.admin_user,
      action: 'permission_assigned',
      details: "Permission #{permission.name} #{status} to role #{role.name}",
      target_type: 'Role',
      target_id: role_id
    )
  rescue => e
    Rails.logger.error "Failed to log permission assignment: #{e.message}"
  end
  
  def log_update
    AdminLog.create!(
      admin_user: Current.admin_user,
      action: 'permission_updated',
      details: "Permission #{permission.name} updated to #{status} for role #{role.name}",
      target_type: 'Role', 
      target_id: role_id
    )
  rescue => e
    Rails.logger.error "Failed to log permission update: #{e.message}"
  end
end