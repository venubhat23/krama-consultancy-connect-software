class Role < ApplicationRecord
  # Associations
  has_many :role_permissions, dependent: :destroy
  has_many :permissions, through: :role_permissions
  has_many :users, dependent: :restrict_with_error
  has_many :sub_agents, dependent: :restrict_with_error

  # Validations
  validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 100 }
  validates :description, length: { maximum: 500 }
  validates :status, inclusion: { in: [true, false] }

  # Scopes
  scope :active, -> { where(status: true) }
  scope :inactive, -> { where(status: false) }

  # Callbacks
  before_validation :normalize_name

  # Class methods
  def self.default_roles
    %w[super_admin admin manager agent customer]
  end

  def self.module_names
    %w[dashboard customers policies health_insurance life_insurance motor_insurance other_insurance
       leads reports analytics users roles permissions settings import_export helpdesk
       forums business_plans forum_requests announcements support_tickets events]
  end

  def self.action_types
    %w[create read update delete export import manage]
  end

  # Instance methods
  def active?
    status
  end

  def inactive?
    !status
  end

  def display_name
    name.titleize
  end

  def user_count
    users.count
  end

  # Permission methods
  def has_permission?(module_name, action_type)
    permissions.exists?(module_name: module_name.to_s, action_type: action_type.to_s)
  end

  def grant_permission(module_name, action_type)
    permission = Permission.find_by(module_name: module_name.to_s, action_type: action_type.to_s)
    return false unless permission

    role_permissions.find_or_create_by(permission: permission)
  end

  def revoke_permission(module_name, action_type)
    permission = Permission.find_by(module_name: module_name.to_s, action_type: action_type.to_s)
    return false unless permission

    role_permissions.where(permission: permission).destroy_all
  end

  def module_permissions(module_name)
    permissions.where(module_name: module_name.to_s).pluck(:action_type)
  end

  def all_modules_with_permissions
    modules_hash = {}
    Role.module_names.each do |module_name|
      modules_hash[module_name] = module_permissions(module_name)
    end
    modules_hash
  end

  private

  def normalize_name
    self.name = name.strip if name.present?
  end
end