# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Starting database seeding..."

# Create default permissions
puts "Creating permissions..."

permissions_data = [
  # User Management
  { name: 'users.view', resource: 'users', action: 'view', description: 'View user list and details' },
  { name: 'users.create', resource: 'users', action: 'create', description: 'Create new users' },
  { name: 'users.update', resource: 'users', action: 'update', description: 'Update user information' },
  { name: 'users.delete', resource: 'users', action: 'delete', description: 'Delete users' },
  { name: 'users.suspend', resource: 'users', action: 'suspend', description: 'Suspend user accounts' },
  { name: 'users.activate', resource: 'users', action: 'activate', description: 'Activate user accounts' },
  { name: 'users.change_plan', resource: 'users', action: 'change_plan', description: 'Change user subscription plans' },
  { name: 'users.view_logs', resource: 'users', action: 'view_logs', description: 'View user activity logs' },
  { name: 'users.impersonate', resource: 'users', action: 'impersonate', description: 'Impersonate users' },
  { name: 'users.export', resource: 'users', action: 'export', description: 'Export user data' },

  # Instagram Account Management
  { name: 'instagram_accounts.view', resource: 'instagram_accounts', action: 'view', description: 'View Instagram accounts' },
  { name: 'instagram_accounts.create', resource: 'instagram_accounts', action: 'create', description: 'Create Instagram accounts' },
  { name: 'instagram_accounts.update', resource: 'instagram_accounts', action: 'update', description: 'Update Instagram accounts' },
  { name: 'instagram_accounts.delete', resource: 'instagram_accounts', action: 'delete', description: 'Delete Instagram accounts' },
  { name: 'instagram_accounts.verify', resource: 'instagram_accounts', action: 'verify', description: 'Verify Instagram accounts' },
  { name: 'instagram_accounts.suspend', resource: 'instagram_accounts', action: 'suspend', description: 'Suspend Instagram accounts' },

  # Automation Management
  { name: 'automations.view', resource: 'automations', action: 'view', description: 'View automations' },
  { name: 'automations.create', resource: 'automations', action: 'create', description: 'Create automations' },
  { name: 'automations.update', resource: 'automations', action: 'update', description: 'Update automations' },
  { name: 'automations.delete', resource: 'automations', action: 'delete', description: 'Delete automations' },
  { name: 'automations.start', resource: 'automations', action: 'start', description: 'Start automations' },
  { name: 'automations.stop', resource: 'automations', action: 'stop', description: 'Stop automations' },
  { name: 'automations.pause', resource: 'automations', action: 'pause', description: 'Pause automations' },

  # Contact Management
  { name: 'contacts.view', resource: 'contacts', action: 'view', description: 'View contacts' },
  { name: 'contacts.create', resource: 'contacts', action: 'create', description: 'Create contacts' },
  { name: 'contacts.update', resource: 'contacts', action: 'update', description: 'Update contacts' },
  { name: 'contacts.delete', resource: 'contacts', action: 'delete', description: 'Delete contacts' },
  { name: 'contacts.export', resource: 'contacts', action: 'export', description: 'Export contacts' },
  { name: 'contacts.import', resource: 'contacts', action: 'import', description: 'Import contacts' },

  # Usage Metrics
  { name: 'usage_metrics.view', resource: 'usage_metrics', action: 'view', description: 'View usage metrics' },
  { name: 'usage_metrics.create', resource: 'usage_metrics', action: 'create', description: 'Create usage metrics' },
  { name: 'usage_metrics.update', resource: 'usage_metrics', action: 'update', description: 'Update usage metrics' },
  { name: 'usage_metrics.delete', resource: 'usage_metrics', action: 'delete', description: 'Delete usage metrics' },
  { name: 'usage_metrics.export', resource: 'usage_metrics', action: 'export', description: 'Export usage metrics' },

  # Analytics
  { name: 'analytics.view', resource: 'analytics', action: 'view', description: 'View analytics dashboard' },
  { name: 'analytics.export', resource: 'analytics', action: 'export', description: 'Export analytics data' },
  { name: 'analytics.advanced', resource: 'analytics', action: 'advanced', description: 'Access advanced analytics features' },

  # Settings Management
  { name: 'settings.view', resource: 'settings', action: 'view', description: 'View system settings' },
  { name: 'settings.manage', resource: 'settings', action: 'manage', description: 'Manage system settings' },
  { name: 'settings.export', resource: 'settings', action: 'export', description: 'Export settings' },
  { name: 'settings.import', resource: 'settings', action: 'import', description: 'Import settings' },

  # Role and Permission Management
  { name: 'roles.view', resource: 'roles', action: 'view', description: 'View roles' },
  { name: 'roles.create', resource: 'roles', action: 'create', description: 'Create roles' },
  { name: 'roles.update', resource: 'roles', action: 'update', description: 'Update roles' },
  { name: 'roles.delete', resource: 'roles', action: 'delete', description: 'Delete roles' },
  { name: 'permissions.view', resource: 'permissions', action: 'view', description: 'View permissions' },
  { name: 'permissions.manage', resource: 'permissions', action: 'manage', description: 'Manage permissions' },

  # Admin User Management
  { name: 'admin_users.view', resource: 'admin_users', action: 'view', description: 'View admin users' },
  { name: 'admin_users.create', resource: 'admin_users', action: 'create', description: 'Create admin users' },
  { name: 'admin_users.update', resource: 'admin_users', action: 'update', description: 'Update admin users' },
  { name: 'admin_users.delete', resource: 'admin_users', action: 'delete', description: 'Delete admin users' },
  { name: 'admin_users.change_role', resource: 'admin_users', action: 'change_role', description: 'Change admin user roles' },

  # Audit Logs
  { name: 'admin_logs.view', resource: 'admin_logs', action: 'view', description: 'View admin activity logs' },
  { name: 'admin_logs.export', resource: 'admin_logs', action: 'export', description: 'Export admin logs' },
  { name: 'user_logs.view', resource: 'user_logs', action: 'view', description: 'View user activity logs' },
  { name: 'user_logs.export', resource: 'user_logs', action: 'export', description: 'Export user logs' },

  # System Management
  { name: 'system.maintenance', resource: 'system', action: 'maintenance', description: 'Access system maintenance features' },
  { name: 'system.backup', resource: 'system', action: 'backup', description: 'Perform system backups' },
  { name: 'system.monitoring', resource: 'system', action: 'monitoring', description: 'Access system monitoring' },

  # Dashboard Access
  { name: 'dashboard.view', resource: 'dashboard', action: 'view', description: 'View admin dashboard' },
  { name: 'dashboard.advanced', resource: 'dashboard', action: 'advanced', description: 'Access advanced dashboard features' }
]

permissions_data.each do |perm_data|
  permission = Permission.find_or_create_by(name: perm_data[:name]) do |p|
    p.resource = perm_data[:resource]
    p.action = perm_data[:action]
    p.description = perm_data[:description]
  end
  puts "  ✅ #{permission.name}"
end

# Create default roles
puts "\nCreating roles..."

roles_data = [
  {
    name: 'Super Admin',
    description: 'Full system access with all permissions',
    priority: 1,
    active: true,
    permissions: Permission.all
  },
  {
    name: 'Admin',
    description: 'General administrative access',
    priority: 2,
    active: true,
    permissions: Permission.where.not(name: ['admin_users.delete', 'system.maintenance', 'system.backup'])
  },
  {
    name: 'User Manager',
    description: 'User and account management',
    priority: 3,
    active: true,
    permissions: Permission.where(resource: ['users', 'instagram_accounts', 'dashboard', 'user_logs'])
  },
  {
    name: 'Analytics Manager',
    description: 'Analytics and reporting access',
    priority: 4,
    active: true,
    permissions: Permission.where(resource: ['analytics', 'usage_metrics', 'dashboard'])
  },
  {
    name: 'Content Moderator',
    description: 'Content and automation moderation',
    priority: 5,
    active: true,
    permissions: Permission.where(resource: ['automations', 'contacts', 'instagram_accounts']).where(action: ['view', 'update', 'suspend'])
  },
  {
    name: 'Read Only',
    description: 'View-only access to most resources',
    priority: 6,
    active: true,
    permissions: Permission.where(action: 'view')
  }
]

roles_data.each do |role_data|
  role = Role.find_or_create_by(name: role_data[:name]) do |r|
    r.description = role_data[:description]
    r.priority = role_data[:priority]
    r.active = role_data[:active]
  end
  
  # Clear existing permissions and add new ones
  role.role_permissions.destroy_all
  role_data[:permissions].each do |permission|
    RolePermission.create!(
      role: role,
      permission: permission,
      granted: true
    )
  end
  
  puts "  ✅ #{role.name} (#{role.permissions.count} permissions)"
end

# Create default admin user
puts "\nCreating default admin user..."

super_admin_role = Role.find_by(name: 'Super Admin')
admin_user = AdminUser.find_or_create_by(email: 'admin@kuposu.co') do |admin|
  admin.name = 'System Administrator'
  admin.password = 'admin123456'
  admin.password_confirmation = 'admin123456'
  admin.role = super_admin_role
  admin.status = 'active'
  admin.last_login_at = Time.current
end

puts "  ✅ Admin user: #{admin_user.email} (Role: #{admin_user.role.name})"
puts "     Default password: admin123456 (Please change immediately!)"

# Create sample users for testing
puts "\nCreating sample users..."

sample_users = [
  {
    email: 'john.doe@example.com',
    password: 'password123',
    plan: 'free',
    created_at: 30.days.ago
  },
  {
    email: 'jane.smith@example.com',
    password: 'password123',
    plan: 'pro',
    created_at: 20.days.ago
  },
  {
    email: 'bob.wilson@example.com',
    password: 'password123',
    plan: 'monthly_pro',
    created_at: 15.days.ago
  },
  {
    email: 'alice.johnson@example.com',
    password: 'password123',
    plan: 'annual_pro',
    created_at: 10.days.ago
  },
  {
    email: 'demo@example.com',
    password: 'password123',
    plan: 'free',
    created_at: 5.days.ago
  }
]

sample_users.each do |user_data|
  user = User.find_or_create_by(email: user_data[:email]) do |u|
    u.password = user_data[:password]
    u.password_confirmation = user_data[:password]
    u.plan = user_data[:plan]
    u.created_at = user_data[:created_at]
  end
  puts "  ✅ #{user.email} (Plan: #{user.plan})"
  
  # Create some sample Instagram accounts
  if user.instagram_accounts.count == 0
    instagram_account = user.instagram_accounts.create!(
      instagram_user_id: "sample_#{user.id}",
      username: "sample_user_#{user.id}",
      access_token: SecureRandom.hex(32),
      token_expires_at: 60.days.from_now,
      status: 'active',
      followers_count: rand(1000..50000),
      following_count: rand(500..5000),
      media_count: rand(50..1000),
      is_verified: [true, false].sample,
      profile_picture_url: "https://example.com/profile_#{user.id}.jpg"
    )
    puts "    📱 Instagram account: @#{instagram_account.username}"
  end
  
  # Create some sample usage metrics
  if user.usage_metrics.count == 0
    30.times do |i|
      date = i.days.ago
      user.usage_metrics.create!(
        metric_type: 'dm_sent',
        count: rand(10..100),
        created_at: date
      )
      
      if rand(3) == 0
        user.usage_metrics.create!(
          metric_type: 'contact_scraped',
          count: rand(50..200),
          created_at: date
        )
      end
    end
    puts "    📊 Usage metrics created"
  end
  
  # Create some sample contacts
  if user.contacts.count == 0
    rand(20..100).times do
      user.contacts.create!(
        instagram_username: "contact_#{SecureRandom.hex(4)}",
        full_name: Faker::Name.name,
        bio: Faker::Lorem.sentence,
        followers_count: rand(100..10000),
        following_count: rand(50..5000),
        is_private: [true, false].sample,
        is_verified: [true, false].sample,
        contact_status: ['active', 'contacted', 'replied', 'not_interested'].sample,
        tags: ['potential_client', 'influencer', 'competitor'].sample(rand(1..2)),
        notes: Faker::Lorem.paragraph,
        created_at: rand(30.days).seconds.ago
      )
    end
    puts "    👥 #{user.contacts.count} contacts created"
  end
  
  # Create some sample automations
  if user.automations.count == 0
    rand(2..5).times do
      automation = user.automations.create!(
        name: "Automation #{SecureRandom.hex(4)}",
        automation_type: ['dm_automation', 'follow_automation', 'like_automation', 'comment_automation'].sample,
        target_criteria: {
          hashtags: ['#marketing', '#business', '#startup'].sample(2),
          location: ['New York', 'Los Angeles', 'London'].sample,
          follower_range: { min: 1000, max: 10000 }
        },
        message_templates: [
          "Hi! I love your content about {{topic}}!",
          "Your post about {{subject}} was amazing!",
          "Would love to collaborate with you!"
        ],
        settings: {
          daily_limit: rand(50..200),
          delay_between_actions: rand(30..120),
          auto_follow: [true, false].sample
        },
        status: ['active', 'paused', 'completed'].sample,
        created_at: rand(30.days).seconds.ago
      )
      
      automation.instagram_accounts << user.instagram_accounts.first if user.instagram_accounts.any?
      puts "    🤖 Automation: #{automation.name} (#{automation.status})"
    end
  end
end

# Create some sample admin logs
puts "\nCreating sample admin logs..."

10.times do
  AdminLog.create!(
    admin_user: admin_user,
    action: ['user_created', 'user_updated', 'user_suspended', 'settings_updated', 'role_assigned'].sample,
    details: "Sample admin action performed during seeding",
    ip_address: ['192.168.1.100', '10.0.0.1', '172.16.0.1'].sample,
    user_agent: 'Admin Seeder',
    created_at: rand(30.days).seconds.ago
  )
end
puts "  ✅ #{AdminLog.count} admin logs created"

# Create some sample user logs
puts "Creating sample user logs..."

User.limit(10).each do |user|
  5.times do
    UserLog.create!(
      user: user,
      action: ['login', 'logout', 'profile_updated', 'instagram_connected', 'automation_created'].sample,
      details: "Sample user action during seeding",
      ip_address: ['192.168.1.100', '10.0.0.1', '172.16.0.1'].sample,
      user_agent: 'User Seeder',
      created_at: rand(30.days).seconds.ago
    )
  end
end
puts "  ✅ #{UserLog.count} user logs created"

puts "\n🎉 Database seeding completed successfully!"
puts "\nDefault Admin Login:"
puts "Email: admin@kuposu.co"
puts "Password: admin123456"
puts "\n⚠️  IMPORTANT: Please change the default admin password immediately!"
puts "\nSample Data Created:"
puts "- #{Permission.count} permissions"
puts "- #{Role.count} roles"
puts "- #{AdminUser.count} admin user(s)"
puts "- #{User.count} users"
puts "- #{InstagramAccount.count} Instagram accounts"
puts "- #{Automation.count} automations"
puts "- #{Contact.count} contacts"
puts "- #{UsageMetric.count} usage metrics"
puts "- #{AdminLog.count} admin logs"
puts "- #{UserLog.count} user logs"