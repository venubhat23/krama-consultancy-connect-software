class Admin::PermissionsController < Admin::ApplicationController
  before_action :set_permission, only: [:show, :edit, :update, :destroy]
  before_action :ensure_super_admin

  # GET /admin/permissions
  def index
    @permissions = Permission.includes(:roles).order(:module_name, :action_type)
    @grouped_permissions = @permissions.group_by(&:module_name)
    @modules = Permission.modules_list
    @actions = Permission.actions_list

    # Statistics
    @total_permissions = @permissions.count
    @modules_count = @permissions.distinct.count(:module_name)
    @assigned_permissions = @permissions.joins(:role_permissions).distinct.count
    @unassigned_permissions = @total_permissions - @assigned_permissions
  end

  # GET /admin/permissions/1
  def show
    @roles_with_permission = @permission.roles.order(:name)
    @roles_without_permission = Role.where.not(id: @permission.roles.pluck(:id)).order(:name)
  end

  # GET /admin/permissions/new
  def new
    @permission = Permission.new
    @modules = Permission.modules_list
    @actions = Permission.actions_list
  end

  # GET /admin/permissions/1/edit
  def edit
    @modules = Permission.modules_list
    @actions = Permission.actions_list
  end

  # POST /admin/permissions
  def create
    @permission = Permission.new(permission_params)

    if @permission.save
      redirect_to admin_permission_path(@permission), notice: 'Permission was successfully created.'
    else
      @modules = Permission.modules_list
      @actions = Permission.actions_list
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /admin/permissions/1
  def update
    if @permission.update(permission_params)
      # Clear cache for all users who have roles with this permission
      clear_affected_users_cache
      redirect_to admin_permission_path(@permission), notice: 'Permission was successfully updated.'
    else
      @modules = Permission.modules_list
      @actions = Permission.actions_list
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/permissions/1
  def destroy
    if @permission.role_permissions.any?
      redirect_to admin_permissions_path,
        alert: "Cannot delete permission '#{@permission.display_name}' as it is assigned to roles."
      return
    end

    @permission.destroy!
    redirect_to admin_permissions_path, notice: "Permission '#{@permission.display_name}' was successfully deleted."
  end

  # POST /admin/permissions/generate_defaults
  def generate_defaults
    begin
      Permission.create_default_permissions
      redirect_to admin_permissions_path, notice: 'Default permissions generated successfully.'
    rescue => e
      redirect_to admin_permissions_path, alert: "Failed to generate default permissions: #{e.message}"
    end
  end

  # GET /admin/permissions/bulk_assign
  def bulk_assign
    @roles = Role.active.order(:name)
    @permissions = Permission.includes(:roles).order(:module_name, :action_type)
    @grouped_permissions = @permissions.group_by(&:module_name)
    @modules = Permission.modules_list

    # Current assignments matrix
    @assignments = {}
    @roles.each do |role|
      @assignments[role.id] = role.permissions.pluck(:id)
    end
  end

  # POST /admin/permissions/bulk_update
  def bulk_update
    assignments = params[:assignments] || {}

    begin
      Permission.transaction do
        assignments.each do |role_id, permission_ids|
          role = Role.find(role_id)
          permission_ids = permission_ids.compact.map(&:to_i)
          RolePermission.bulk_assign_permissions(role, permission_ids)

          # Clear cache for users with this role
          role.users.find_each(&:clear_abilities_cache)
        end
      end

      redirect_to admin_permissions_path, notice: 'Permission assignments updated successfully.'
    rescue => e
      redirect_to bulk_assign_admin_permissions_path, alert: "Failed to update assignments: #{e.message}"
    end
  end

  # GET /admin/permissions/module/:module_name
  def module_permissions
    @module_name = params[:module_name]
    @module_info = Permission.modules_list.find { |m| m[:name] == @module_name }
    @permissions = Permission.where(module_name: @module_name).includes(:roles).order(:action_type)
    @roles = Role.active.order(:name)

    if @module_info.nil?
      redirect_to admin_permissions_path, alert: "Module '#{@module_name}' not found."
      return
    end

    # Role assignments for this module
    @role_assignments = {}
    @roles.each do |role|
      @role_assignments[role.id] = role.permissions.where(module_name: @module_name).pluck(:action_type)
    end
  end

  private

  def set_permission
    @permission = Permission.find(params[:id])
  end

  def permission_params
    params.require(:permission).permit(:name, :module_name, :action_type, :description)
  end

  def ensure_super_admin
    unless current_user.has_permission?('roles', 'manage') || current_user.super_admin?
      redirect_to admin_dashboard_index_path, alert: "You don't have permission to manage permissions."
      return false
    end
  end

  def clear_affected_users_cache
    # Clear cache for all users who have roles with this permission
    role_ids = @permission.roles.pluck(:id)
    User.where(role_id: role_ids).find_each(&:clear_abilities_cache)
  end
end