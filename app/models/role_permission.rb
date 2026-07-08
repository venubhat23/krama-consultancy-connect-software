class RolePermission < ApplicationRecord
  # Associations
  belongs_to :role
  belongs_to :permission

  # Validations
  validates :role_id, presence: true
  validates :permission_id, presence: true
  validates :role_id, uniqueness: { scope: :permission_id }

  # Scopes
  scope :for_role, ->(role) { where(role: role) }
  scope :for_permission, ->(permission) { where(permission: permission) }
  scope :for_module, ->(module_name) { joins(:permission).where(permissions: { module_name: module_name }) }
  scope :for_action, ->(action_type) { joins(:permission).where(permissions: { action_type: action_type }) }

  # Callbacks
  after_create :clear_user_abilities_cache
  after_destroy :clear_user_abilities_cache

  # Class methods
  def self.bulk_assign_permissions(role, permission_ids)
    transaction do
      # Remove existing permissions for this role
      where(role: role).destroy_all

      # Add new permissions
      permission_ids.each do |permission_id|
        create!(role: role, permission_id: permission_id)
      end
    end
  end

  def self.permissions_for_role(role)
    includes(:permission).where(role: role).map(&:permission)
  end

  def self.modules_for_role(role)
    joins(:permission)
      .where(role: role)
      .select('DISTINCT permissions.module_name')
      .pluck('permissions.module_name')
  end

  def self.actions_for_role_and_module(role, module_name)
    joins(:permission)
      .where(role: role, permissions: { module_name: module_name })
      .pluck('permissions.action_type')
  end

  # Instance methods
  def permission_name
    permission.display_name
  end

  def module_name
    permission.module_name
  end

  def action_type
    permission.action_type
  end

  private

  def clear_user_abilities_cache
    # Clear abilities cache for all users with this role
    # This ensures permission changes take effect immediately
    role.users.find_each do |user|
      Rails.cache.delete("user_#{user.id}_abilities")
    end
  end
end