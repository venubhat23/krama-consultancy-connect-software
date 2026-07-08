class Admin::RolesController < Admin::ApplicationController
  before_action :set_role, only: [:show, :edit, :update, :destroy, :toggle_status]
  before_action :ensure_not_deleting_own_role, only: [:destroy]
  before_action :ensure_super_admin, only: [:create, :update, :destroy]

  # GET /admin/roles
  def index
    @roles = Role.includes(:permissions, :users).order(:name)
    @permissions_count = Permission.count
    @users_count = User.count

    # Statistics
    @active_roles = @roles.where(status: true).count
    @inactive_roles = @roles.where(status: false).count
    @total_assignments = @roles.joins(:users).count
  end

  # GET /admin/roles/1
  def show
    @users = @role.users.includes(:role).order(:first_name, :last_name)
    @permissions = @role.permissions.includes(:roles).group_by(&:module_name)
    @all_modules = Permission.modules_list
    @available_users = User.where(role: nil).or(User.where.not(role: @role))
  end

  # GET /admin/roles/new
  def new
    @role = Role.new
    @permissions = Permission.includes(:roles).group_by(&:module_name)
    @modules = Permission.modules_list.map { |m| m[:name] }
  end

  # GET /admin/roles/1/edit
  def edit
    @permissions = Permission.includes(:roles).group_by(&:module_name)
    @modules = Permission.modules_list.map { |m| m[:name] }
    @role_permissions = @role.permissions.pluck(:id)
  end

  # POST /admin/roles
  def create
    @role = Role.new(role_params)

    if @role.save
      assign_permissions if params[:permission_ids].present?
      redirect_to admin_role_path(@role), notice: 'Role was successfully created.'
    else
      @permissions = Permission.includes(:roles).group_by(&:module_name)
      @modules = Permission.modules_list.map { |m| m[:name] }
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /admin/roles/1
  def update
    if @role.update(role_params)
      assign_permissions if params[:permission_ids].present?
      redirect_to admin_role_path(@role), notice: 'Role was successfully updated.'
    else
      @permissions = Permission.includes(:roles).group_by(&:module_name)
      @modules = Permission.modules_list.map { |m| m[:name] }
      @role_permissions = @role.permissions.pluck(:id)
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/roles/1
  def destroy
    if @role.users.any?
      redirect_to admin_roles_path,
        alert: "Cannot delete role '#{@role.display_name}' as it is assigned to #{@role.users.count} user(s)."
      return
    end

    @role.destroy!
    redirect_to admin_roles_path, notice: "Role '#{@role.display_name}' was successfully deleted."
  end

  # PATCH /admin/roles/1/toggle_status
  def toggle_status
    @role.update(status: !@role.status)
    status_text = @role.status? ? 'activated' : 'deactivated'
    redirect_to admin_roles_path, notice: "Role '#{@role.display_name}' was successfully #{status_text}."
  end

  # POST /admin/roles/1/assign_users
  def assign_users
    @role = Role.find(params[:id])
    user_ids = params[:user_ids] || []

    begin
      User.transaction do
        # Remove role from users not in the list
        @role.users.where.not(id: user_ids).update_all(role_id: nil)

        # Assign role to selected users
        User.where(id: user_ids).update_all(role_id: @role.id)

        # Clear abilities cache for affected users
        User.where(id: user_ids).find_each(&:clear_abilities_cache)
      end

      redirect_to admin_role_path(@role), notice: 'User assignments updated successfully.'
    rescue => e
      redirect_to admin_role_path(@role), alert: "Failed to update user assignments: #{e.message}"
    end
  end

  # GET /admin/roles/permissions_preview
  def permissions_preview
    permission_ids = params[:permission_ids] || []
    @permissions = Permission.where(id: permission_ids)
                            .includes(:roles)
                            .group_by(&:module_name)
    @modules = Permission.modules_list

    render partial: 'permissions_preview'
  end

  private

  def set_role
    @role = Role.find(params[:id])
  end

  def role_params
    params.require(:role).permit(:name, :description, :status)
  end

  def assign_permissions
    permission_ids = params[:permission_ids].compact.map(&:to_i)
    RolePermission.bulk_assign_permissions(@role, permission_ids)

    # Clear abilities cache for all users with this role
    @role.users.find_each(&:clear_abilities_cache)
  end

  def ensure_not_deleting_own_role
    if current_user.role == @role
      redirect_to admin_roles_path, alert: "You cannot delete your own role."
      return false
    end
  end

  def ensure_super_admin
    unless current_user&.admin? || current_user&.user_type == 'admin' || current_user.has_permission?('roles', 'manage') || current_user.super_admin?
      redirect_to admin_roles_path, alert: "You don't have permission to perform this action."
      return false
    end
  end
end