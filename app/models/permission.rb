class Permission < ApplicationRecord
  # Associations
  has_many :role_permissions, dependent: :destroy
  has_many :roles, through: :role_permissions

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :module_name, presence: true, length: { maximum: 50 }
  validates :action_type, presence: true, length: { maximum: 20 }
  validates :description, length: { maximum: 500 }

  # Unique constraint for module_name and action_type combination
  validates :module_name, uniqueness: { scope: :action_type }

  # Valid action types (using constants instead of enum to avoid conflicts)
  VALID_ACTION_TYPES = %w[create read update delete export import manage].freeze
  validates :action_type, inclusion: { in: VALID_ACTION_TYPES }

  # Scopes
  scope :for_module, ->(module_name) { where(module_name: module_name) }
  scope :for_action, ->(action_type) { where(action_type: action_type) }
  scope :ordered, -> { order(:module_name, :action_type) }

  # Callbacks
  before_validation :normalize_fields

  # Class methods
  def self.modules_list
    [
      { name: 'dashboard', display: 'Dashboard', description: 'Main dashboard and analytics overview' },
      { name: 'customers', display: 'Customers', description: 'Customer management and profiles' },
      { name: 'policies', display: 'Policies', description: 'Policy management and tracking' },
      { name: 'health_insurance', display: 'Health Insurance', description: 'Health insurance policies and claims' },
      { name: 'life_insurance', display: 'Life Insurance', description: 'Life insurance policies and claims' },
      { name: 'motor_insurance', display: 'Motor Insurance', description: 'Motor insurance policies and claims' },
      { name: 'other_insurance', display: 'Other Insurance', description: 'Other types of insurance policies' },
      { name: 'leads', display: 'Leads', description: 'Lead management and conversion tracking' },
      { name: 'reports', display: 'Reports', description: 'Reporting and analytics features' },
      { name: 'analytics', display: 'Analytics', description: 'Advanced analytics and insights' },
      { name: 'users', display: 'Users', description: 'User account management' },
      { name: 'roles', display: 'Roles & Permissions', description: 'Role and permission management' },
      { name: 'settings', display: 'Settings', description: 'System configuration and preferences' },
      { name: 'import_export', display: 'Import/Export', description: 'Data import and export features' },
      { name: 'helpdesk', display: 'Helpdesk', description: 'Customer support and helpdesk' }
    ]
  end

  def self.actions_list
    [
      { name: 'create', display: 'Create', description: 'Create new records' },
      { name: 'read', display: 'Read', description: 'View and read records' },
      { name: 'update', display: 'Update', description: 'Edit and update existing records' },
      { name: 'delete', display: 'Delete', description: 'Delete records permanently' },
      { name: 'export', display: 'Export', description: 'Export data to external formats' },
      { name: 'import', display: 'Import', description: 'Import data from external sources' },
      { name: 'manage', display: 'Manage', description: 'Full management access (all CRUD operations)' }
    ]
  end

  def self.create_default_permissions
    modules_list.each do |module_info|
      actions_list.each do |action_info|
        find_or_create_by(
          module_name: module_info[:name],
          action_type: action_info[:name]
        ) do |permission|
          permission.name = "#{action_info[:display]} #{module_info[:display]}"
          permission.description = "#{action_info[:description]} for #{module_info[:description]}"
        end
      end
    end
  end

  def self.grouped_by_module
    ordered.group_by(&:module_name)
  end

  # Instance methods
  def display_name
    name.present? ? name : "#{action_type.humanize} #{module_name.humanize}"
  end

  def module_display_name
    module_info = self.class.modules_list.find { |m| m[:name] == module_name }
    module_info ? module_info[:display] : module_name.humanize
  end

  def action_display_name
    action_info = self.class.actions_list.find { |a| a[:name] == action_type }
    action_info ? action_info[:display] : action_type.humanize
  end

  def full_description
    description.present? ? description : "#{action_display_name} access for #{module_display_name} module"
  end

  private

  def normalize_fields
    self.module_name = module_name.strip.downcase if module_name.present?
    self.action_type = action_type.strip.downcase if action_type.present?
    self.name = name.strip if name.present?
  end
end