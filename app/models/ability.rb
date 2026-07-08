# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new # guest user (not logged in)

    # If user has no role, grant minimal access
    unless user.role
      grant_guest_abilities(user)
      return
    end

    # Role-based permissions
    grant_role_based_abilities(user)

    # Common abilities for all authenticated users
    if user.persisted?
      can :read, :dashboard
      can [:show, :edit, :update], User, id: user.id
    end
  end

  private

  def grant_guest_abilities(user)
    if user.persisted?
      can :read, :dashboard
      can [:show, :edit, :update], User, id: user.id
    end
  end

  def grant_role_based_abilities(user)
    role = user.role

    # Process each permission for the user's role
    role.permissions.includes(:role_permissions).find_each do |permission|
      grant_permission(user, permission.module_name, permission.action_type)
    end

    # Special handling for super admin
    if user.has_role?('super_admin')
      can :manage, :all
    end
  end

  def grant_permission(user, module_name, action_type)
    case module_name
    when 'dashboard'
      grant_dashboard_permissions(user, action_type)
    when 'customers'
      grant_customer_permissions(user, action_type)
    when 'policies'
      grant_policy_permissions(user, action_type)
    when 'health_insurance'
      grant_health_insurance_permissions(user, action_type)
    when 'life_insurance'
      grant_life_insurance_permissions(user, action_type)
    when 'motor_insurance'
      grant_motor_insurance_permissions(user, action_type)
    when 'other_insurance'
      grant_other_insurance_permissions(user, action_type)
    when 'leads'
      grant_lead_permissions(user, action_type)
    when 'reports'
      grant_report_permissions(user, action_type)
    when 'analytics'
      grant_analytics_permissions(user, action_type)
    when 'users'
      grant_user_permissions(user, action_type)
    when 'roles'
      grant_role_permissions(user, action_type)
    when 'settings'
      grant_settings_permissions(user, action_type)
    when 'import_export'
      grant_import_export_permissions(user, action_type)
    when 'helpdesk'
      grant_helpdesk_permissions(user, action_type)
    end
  end

  def grant_dashboard_permissions(user, action_type)
    case action_type
    when 'read'
      can :read, :dashboard
      can :index, Admin::DashboardController
    when 'manage'
      can :manage, :dashboard
      can :manage, Admin::DashboardController
    end
  end

  def grant_customer_permissions(user, action_type)
    case action_type
    when 'create'
      can :create, Customer
      can :new, Customer
    when 'read'
      can :read, Customer
      can [:index, :show], Customer
    when 'update'
      can :update, Customer
      can [:edit, :toggle_status], Customer
    when 'delete'
      can :destroy, Customer
    when 'export'
      can :export, Customer
    when 'manage'
      can :manage, Customer
    end
  end

  def grant_policy_permissions(user, action_type)
    case action_type
    when 'create'
      can :create, Policy
    when 'read'
      can :read, Policy
    when 'update'
      can :update, Policy
    when 'delete'
      can :destroy, Policy
    when 'export'
      can :export, Policy
    when 'manage'
      can :manage, Policy
    end
  end

  def grant_health_insurance_permissions(user, action_type)
    case action_type
    when 'create'
      can :create, HealthInsurance
    when 'read'
      can :read, HealthInsurance
    when 'update'
      can :update, HealthInsurance
    when 'delete'
      can :destroy, HealthInsurance
    when 'export'
      can :export, HealthInsurance
    when 'manage'
      can :manage, HealthInsurance
    end
  end

  def grant_life_insurance_permissions(user, action_type)
    case action_type
    when 'create'
      can :create, LifeInsurance
    when 'read'
      can :read, LifeInsurance
    when 'update'
      can :update, LifeInsurance
    when 'delete'
      can :destroy, LifeInsurance
    when 'export'
      can :export, LifeInsurance
    when 'manage'
      can :manage, LifeInsurance
    end
  end

  def grant_motor_insurance_permissions(user, action_type)
    case action_type
    when 'create'
      can :create, MotorInsurance
    when 'read'
      can :read, MotorInsurance
    when 'update'
      can :update, MotorInsurance
    when 'delete'
      can :destroy, MotorInsurance
    when 'export'
      can :export, MotorInsurance
    when 'manage'
      can :manage, MotorInsurance
    end
  end

  def grant_other_insurance_permissions(user, action_type)
    case action_type
    when 'create'
      can :create, OtherInsurance
    when 'read'
      can :read, OtherInsurance
    when 'update'
      can :update, OtherInsurance
    when 'delete'
      can :destroy, OtherInsurance
    when 'export'
      can :export, OtherInsurance
    when 'manage'
      can :manage, OtherInsurance
    end
  end

  def grant_lead_permissions(user, action_type)
    case action_type
    when 'create'
      can :create, Lead
    when 'read'
      can :read, Lead
    when 'update'
      can :update, Lead
    when 'delete'
      can :destroy, Lead
    when 'export'
      can :export, Lead
    when 'manage'
      can :manage, Lead
    end
  end

  def grant_report_permissions(user, action_type)
    case action_type
    when 'read'
      can :read, :reports
      can :all, Admin::ReportsController
    when 'export'
      can :export, :reports
    when 'manage'
      can :manage, :reports
      can :manage, Admin::ReportsController
    end
  end

  def grant_analytics_permissions(user, action_type)
    case action_type
    when 'read'
      can :read, :analytics
    when 'manage'
      can :manage, :analytics
    end
  end

  def grant_user_permissions(user, action_type)
    case action_type
    when 'create'
      can :create, User
    when 'read'
      can :read, User
    when 'update'
      can :update, User
    when 'delete'
      can :destroy, User
    when 'manage'
      can :manage, User
    end
  end

  def grant_role_permissions(user, action_type)
    case action_type
    when 'read'
      can :read, [Role, Permission, RolePermission]
    when 'manage'
      can :manage, [Role, Permission, RolePermission]
    end
  end

  def grant_settings_permissions(user, action_type)
    case action_type
    when 'read'
      can :read, :settings
    when 'update'
      can :update, :settings
    when 'manage'
      can :manage, :settings
    end
  end

  def grant_import_export_permissions(user, action_type)
    case action_type
    when 'import'
      can :import, :all
    when 'export'
      can :export, :all
    when 'manage'
      can [:import, :export], :all
    end
  end

  def grant_helpdesk_permissions(user, action_type)
    case action_type
    when 'create'
      can :create, :helpdesk
    when 'read'
      can :read, :helpdesk
    when 'update'
      can :update, :helpdesk
    when 'delete'
      can :destroy, :helpdesk
    when 'manage'
      can :manage, :helpdesk
    end
  end
end
