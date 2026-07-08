class Admin::ProfileController < Admin::ApplicationController
  before_action :set_current_user

  def show
    # Show current user profile information
  end

  def edit
    # Allow editing of profile information
  end

  def update
    if @current_user.update(profile_params)
      redirect_to admin_profile_path, notice: 'Profile updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_current_user
    @current_user = current_user
  end

  def profile_params
    params.require(:user).permit(:first_name, :last_name, :email, :mobile, :password, :password_confirmation)
  end
end