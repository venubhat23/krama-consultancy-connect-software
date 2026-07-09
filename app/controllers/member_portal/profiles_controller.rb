module MemberPortal
  class ProfilesController < ApplicationController
    def edit
      @user = current_user
    end

    def update
      if current_user.update(profile_params)
        redirect_to edit_member_portal_profile_path, notice: "Your business profile has been updated."
      else
        @user = current_user
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def profile_params
      params.require(:user).permit(:company_name, :designation, :business_category, :speciality, :nature_of_business, :website)
    end
  end
end
