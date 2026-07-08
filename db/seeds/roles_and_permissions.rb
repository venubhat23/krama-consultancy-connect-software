puts "🔐 Creating default roles and permissions..."

# First, create default permissions
puts "📋 Creating permissions..."
Permission.create_default_permissions
puts "✅ Created #{Permission.count} permissions"

# Define default roles with their configurations
roles_config = {
  'super_admin' => {
    name: 'super_admin',
    description: 'Full system access with all privileges. Can manage all users, roles, and system settings.',
    status: true,
    permissions: 'all'
  },
  'admin' => {
    name: 'admin',
    description: 'Administrative access with full CRUD operations on all insurance modules. Cannot manage roles and users.',
    status: true,
    permissions: %w[
      dashboard customers policies health_insurance life_insurance motor_insurance
      other_insurance leads reports analytics import_export helpdesk settings
    ]
  },
  'manager' => {
    name: 'manager',
    description: 'Management level access with read/update permissions and report access. Limited creation rights.',
    status: true,
    permissions: %w[dashboard customers policies health_insurance life_insurance motor_insurance other_insurance leads reports analytics]
  },
  'agent' => {
    name: 'agent',
    description: 'Agent access limited to customer and policy management. Can create and manage own customer policies.',
    status: true,
    permissions: %w[dashboard customers policies health_insurance life_insurance motor_insurance other_insurance leads]
  },
  'customer' => {
    name: 'customer',
    description: 'Customer access with read-only permissions to their own policies and basic dashboard.',
    status: true,
    permissions: %w[dashboard]
  },
  'sub_agent' => {
    name: 'sub_agent',
    description: 'Sub-agent/affiliate access limited to their assigned customers and policies.',
    status: true,
    permissions: %w[dashboard customers policies health_insurance life_insurance motor_insurance other_insurance leads]
  }
}

# Create roles and assign permissions
roles_config.each do |role_key, config|
  puts "\n👤 Creating role: #{config[:name]}"

  role = Role.find_or_create_by(name: config[:name]) do |r|
    r.description = config[:description]
    r.status = config[:status]
  end

  puts "  📝 Role: #{role.display_name}"

  # Assign permissions
  if config[:permissions] == 'all'
    # Super admin gets all permissions
    permissions = Permission.all
  else
    # Other roles get specific module permissions
    module_names = config[:permissions]
    permissions = []

    module_names.each do |module_name|
      case role.name
      when 'admin'
        # Admin gets manage permission for all assigned modules
        permissions += Permission.where(module_name: module_name, action_type: ['read', 'create', 'update', 'delete', 'export'])
      when 'manager'
        # Manager gets read/update permissions
        permissions += Permission.where(module_name: module_name, action_type: ['read', 'update'])
      when 'agent'
        # Agent gets create/read/update permissions for customer-facing modules
        if %w[customers policies health_insurance life_insurance motor_insurance other_insurance leads].include?(module_name)
          permissions += Permission.where(module_name: module_name, action_type: ['create', 'read', 'update'])
        else
          permissions += Permission.where(module_name: module_name, action_type: ['read'])
        end
      when 'customer'
        # Customer gets only read permissions
        permissions += Permission.where(module_name: module_name, action_type: ['read'])
      end
    end
  end

  # Clear existing permissions and assign new ones
  role.role_permissions.destroy_all
  permissions.each do |permission|
    RolePermission.create!(role: role, permission: permission)
  end

  puts "  ✅ Assigned #{permissions.count} permissions"
end

# Update existing users to have roles (migration from old enum system)
puts "\n👥 Updating existing users with roles..."

# Find or create roles for existing users based on their current user_type
User.where(role: nil).find_each do |user|
  role_name = case user.user_type
  when 'admin'
    # Check if they were a super admin in the old system
    if user.respond_to?(:role) && user.role == 'super_admin'
      'super_admin'
    else
      'admin'
    end
  when 'agent'
    'agent'
  when 'sub_agent'
    'agent'  # Map sub_agent to agent role
  when 'customer'
    'customer'
  else
    'customer'  # Default fallback
  end

  role = Role.find_by(name: role_name)
  if role
    user.update!(role: role)
    puts "  ✅ Assigned #{role_name} role to #{user.email}"
  end
end

puts "\n📊 Roles and Permissions Summary:"
puts "  🔐 Total Roles: #{Role.count}"
puts "  📋 Total Permissions: #{Permission.count}"
puts "  🔗 Total Assignments: #{RolePermission.count}"
puts "  👥 Users with Roles: #{User.where.not(role: nil).count}"

Role.includes(:users, :permissions).each do |role|
  puts "  #{role.display_name}: #{role.users.count} users, #{role.permissions.count} permissions"
end

puts "\n✅ Roles and permissions setup completed!"