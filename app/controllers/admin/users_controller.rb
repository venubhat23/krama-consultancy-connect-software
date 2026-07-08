class Admin::UsersController < Admin::ApplicationController
  before_action :set_user, only: [:show, :edit, :update, :destroy]

  # GET /admin/users
  def index
    @users = User.all

    # Search functionality
    if params[:search].present?
      @users = @users.search_users(params[:search])
    end

    # Filter by user type
    if params[:user_type].present?
      @users = @users.where(user_type: params[:user_type])
    end

    # Filter by status
    case params[:status]
    when 'active'
      @users = @users.active
    when 'inactive'
      @users = @users.inactive
    end

    @users = @users.order(created_at: :desc).page(params[:page])

    # Statistics
    @total_users = User.count
    @active_users = User.active.count
    @admin_users = User.where(user_type: 'admin').count
    @agent_users = User.where(user_type: ['agent', 'sub_agent']).count
  end

  # GET /admin/users/1
  def show
    @policies = @user.policies.includes(:customer, :insurance_company).order(created_at: :desc).limit(10)
  end

  # GET /admin/users/new
  def new
    @user = User.new
  end

  # GET /admin/users/1/edit
  def edit
  end

  # POST /admin/users
  def create
    @user = User.new(user_params)
    @user.write_attribute(:role, params.dig(:user, :role).presence)

    if @user.save
      redirect_to admin_user_path(@user), notice: 'User was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /admin/users/1
  def update
    @user.assign_attributes(user_params)
    @user.write_attribute(:role, params.dig(:user, :role).presence)

    @user.clean_up_passwords if @user.password.blank? && @user.password_confirmation.blank?
    if @user.save
      redirect_to admin_user_path(@user), notice: 'User was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/users/1
  def destroy
    if @user.policies.exists?
      redirect_to admin_users_path, alert: 'Cannot delete user with existing policies.'
    else
      @user.destroy
      redirect_to admin_users_path, notice: 'User was successfully deleted.'
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(
      :first_name, :middle_name, :last_name, :email, :mobile, :user_type, :status,
      :address, :state, :city, :pan_number, :gst_number, :date_of_birth, :gender,
      :occupation, :annual_income, :password, :password_confirmation, :company_name,
      :bank_name, :account_no, :ifsc_code, :account_holder_name, :account_type, :upi_id,
      :profile_image, documents: []
    )
  end
end