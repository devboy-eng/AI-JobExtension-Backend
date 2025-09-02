class Admin::RolesController < Admin::BaseController
  before_action :set_role, only: [:show, :update, :destroy, :assign_permissions]
  
  required_permission 'roles.view'
  
  def index
    roles = Role.includes(:permissions, :admin_users).active.ordered
    
    log_admin_activity('roles_listed', 'Viewed roles list')
    
    render json: {
      success: true,
      roles: roles.map { |role| role_summary(role) }
    }
  end
  
  def show
    log_admin_activity('role_viewed', "Viewed role: #{@role.name}", @role)
    
    render json: {
      success: true,
      role: detailed_role_response(@role)
    }
  end
  
  def create
    return error_response('Insufficient permissions', :forbidden) unless current_admin_user.can?('roles.create')
    
    role = Role.new(role_params)
    
    if role.save
      log_admin_activity('role_created', "Created role: #{role.name}", role)
      render json: {
        success: true,
        role: detailed_role_response(role),
        message: 'Role created successfully'
      }
    else
      error_response('Role creation failed', :unprocessable_entity, role.errors.full_messages)
    end
  end
  
  def update
    return error_response('Insufficient permissions', :forbidden) unless current_admin_user.can?('roles.edit')
    
    if @role.update(role_params)
      log_admin_activity('role_updated', "Updated role: #{@role.name}", @role)
      render json: {
        success: true,
        role: detailed_role_response(@role),
        message: 'Role updated successfully'
      }
    else
      error_response('Role update failed', :unprocessable_entity, @role.errors.full_messages)
    end
  end
  
  def destroy
    return error_response('Insufficient permissions', :forbidden) unless current_admin_user.can?('roles.delete')
    
    if @role.admin_users.exists?
      return error_response('Cannot delete role with assigned users', :unprocessable_entity)
    end
    
    role_name = @role.name
    
    if @role.destroy
      log_admin_activity('role_deleted', "Deleted role: #{role_name}")
      success_response({}, 'Role deleted successfully')
    else
      error_response('Role deletion failed', :unprocessable_entity, @role.errors.full_messages)
    end
  end
  
  def assign_permissions
    return error_response('Insufficient permissions', :forbidden) unless current_admin_user.can?('roles.permissions')
    
    permissions_data = params[:permissions] || {}
    assigned_count = 0
    revoked_count = 0
    
    permissions_data.each do |permission_name, granted|
      if @role.grant_permission(permission_name, granted: granted)
        if granted
          assigned_count += 1
        else
          revoked_count += 1
        end
      end
    end
    
    log_admin_activity('permissions_assigned', 
                      "Updated permissions for role #{@role.name}: #{assigned_count} granted, #{revoked_count} revoked", 
                      @role)
    
    render json: {
      success: true,
      role: detailed_role_response(@role),
      message: "Permissions updated: #{assigned_count} granted, #{revoked_count} revoked"
    }
  end
  
  def permissions
    permissions = Permission.all.group_by(&:resource)
    
    render json: {
      success: true,
      permissions: permissions.transform_values do |perms|
        perms.map do |perm|
          {
            id: perm.id,
            name: perm.name,
            action: perm.action,
            description: perm.description
          }
        end
      end
    }
  end
  
  def seed_default_roles
    return error_response('Insufficient permissions', :forbidden) unless current_admin_user.can?('roles.create')
    
    default_roles = [
      {
        name: 'Super Admin',
        description: 'Complete access to all platform features, system settings, and administrative controls',
        color: '#dc2626',
        priority: 1,
        permissions: Permission.pluck(:name) # All permissions
      },
      {
        name: 'Platform Admin',
        description: 'Administrative access to most features except critical system configurations',
        color: '#2563eb',
        priority: 2,
        permissions: Permission.where.not(name: ['system.manage', 'roles.delete', 'admin_users.delete']).pluck(:name)
      },
      {
        name: 'Business Manager',
        description: 'Can manage business operations, users, and view comprehensive analytics',
        color: '#059669',
        priority: 3,
        permissions: %w[
          dashboard.view users.view users.edit users.suspend automations.view automations.edit
          analytics.view financial.view support.view support.edit
        ]
      },
      {
        name: 'Support Manager',
        description: 'Advanced support capabilities with user management and automation oversight',
        color: '#7c3aed',
        priority: 4,
        permissions: %w[
          dashboard.view users.view users.edit automations.view support.view 
          support.edit support.assign analytics.view
        ]
      },
      {
        name: 'Support Agent',
        description: 'Customer support access with limited user management capabilities',
        color: '#0891b2',
        priority: 5,
        permissions: %w[dashboard.view support.view support.edit users.view]
      },
      {
        name: 'Analyst',
        description: 'Read-only access to analytics, reports, and dashboard insights',
        color: '#ea580c',
        priority: 6,
        permissions: %w[dashboard.view analytics.view analytics.export]
      }
    ]
    
    created_roles = []
    
    default_roles.each do |role_data|
      next if Role.exists?(name: role_data[:name])
      
      role = Role.create!(
        name: role_data[:name],
        description: role_data[:description],
        color: role_data[:color],
        priority: role_data[:priority]
      )
      
      # Assign permissions
      role_data[:permissions].each do |permission_name|
        role.grant_permission(permission_name, granted: true)
      end
      
      created_roles << role
    end
    
    log_admin_activity('default_roles_seeded', "Created #{created_roles.count} default roles: #{created_roles.map(&:name).join(', ')}")
    
    render json: {
      success: true,
      created_roles: created_roles.map { |role| role_summary(role) },
      message: "#{created_roles.count} default roles created successfully"
    }
  end
  
  private
  
  def set_role
    @role = Role.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Role not found' }, status: :not_found
  end
  
  def role_params
    params.require(:role).permit(:name, :description, :color, :priority, :active)
  end
  
  def role_summary(role)
    {
      id: role.id,
      name: role.name,
      description: role.description,
      color: role.color,
      priority: role.priority,
      active: role.active,
      users_count: role.admin_users.count,
      permissions_count: role.permissions.count,
      permission_summary: role.permission_summary,
      created_at: role.created_at.strftime('%Y-%m-%d'),
      updated_at: role.updated_at.strftime('%Y-%m-%d %H:%M')
    }
  end
  
  def detailed_role_response(role)
    permissions_by_resource = role.permissions.group_by(&:resource)
    
    role_summary(role).merge(
      permissions: permissions_by_resource.transform_values do |perms|
        perms.map do |perm|
          role_permission = role.role_permissions.find_by(permission: perm)
          {
            id: perm.id,
            name: perm.name,
            action: perm.action,
            description: perm.description,
            granted: role_permission&.granted? || false,
            conditions: role_permission&.conditions
          }
        end
      end,
      assigned_users: role.admin_users.map do |admin_user|
        {
          id: admin_user.id,
          email: admin_user.email,
          full_name: admin_user.full_name,
          status: admin_user.status,
          last_login_at: admin_user.last_login_at&.strftime('%Y-%m-%d %H:%M')
        }
      end
    )
  end
end