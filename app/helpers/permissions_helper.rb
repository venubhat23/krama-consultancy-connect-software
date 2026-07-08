module PermissionsHelper
  def can_view?(module_key)
    # Super admin always has full access
    return true if is_super_admin?
    check_permission(module_key, 'view')
  end

  def can_create?(module_key)
    # Super admin always has full access
    return true if is_super_admin?
    check_permission(module_key, 'create')
  end

  def can_edit?(module_key)
    # Super admin always has full access
    return true if is_super_admin?
    check_permission(module_key, 'edit')
  end

  def can_delete?(module_key)
    # Super admin always has full access
    return true if is_super_admin?
    check_permission(module_key, 'delete')
  end

  def has_any_permission?(module_key)
    # Super admin always has full access
    return true if is_super_admin?
    can_view?(module_key)
  end

  def is_super_admin?
    # admin@drwise.com always has full admin access
    return true if current_user.email == 'admin@drwise.com'
    # Regular admins without specific role assignments also have full access
    current_user.user_type == 'admin' && current_user.role_name.blank?
  end

  private

  def check_permission(module_key, action)
    return false unless current_user.sidebar_permissions.present?

    begin
      permissions = JSON.parse(current_user.sidebar_permissions)

      # Check if it's old format (array of strings)
      if permissions.is_a?(Array)
        # Old format only had view permissions
        return action == 'view' && permissions.include?(module_key)
      end

      # New CRUD format
      return false unless permissions[module_key]
      permissions[module_key][action] == true
    rescue JSON::ParserError
      false
    end
  end

  # Helper to show/hide buttons in views
  def show_create_button?(module_key)
    can_create?(module_key)
  end

  def show_edit_button?(module_key)
    can_edit?(module_key)
  end

  def show_delete_button?(module_key)
    can_delete?(module_key)
  end

  # Get all permissions for a module
  def get_module_permissions(module_key)
    return { view: true, create: true, edit: true, delete: true } if current_user.user_type == 'admin' && current_user.role_name.blank?

    begin
      return { view: false, create: false, edit: false, delete: false } unless current_user.sidebar_permissions.present?

      permissions = JSON.parse(current_user.sidebar_permissions)

      # Check if it's old format (array of strings)
      if permissions.is_a?(Array)
        # Old format only had view permissions
        has_view = permissions.include?(module_key)
        return { view: has_view, create: false, edit: false, delete: false }
      end

      # New CRUD format
      module_perms = permissions[module_key] || {}
      {
        view: module_perms['view'] == true,
        create: module_perms['create'] == true,
        edit: module_perms['edit'] == true,
        delete: module_perms['delete'] == true
      }
    rescue JSON::ParserError
      { view: false, create: false, edit: false, delete: false }
    end
  end
end