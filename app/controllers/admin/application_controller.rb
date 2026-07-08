class Admin::ApplicationController < ApplicationController
  helper InsuranceCompanyHelper
  include InsuranceCompanyHelper

  before_action :ensure_admin

  # Disable CanCanCan for admin controllers
  skip_authorization_check if respond_to?(:skip_authorization_check)
  skip_load_and_authorize_resource if respond_to?(:skip_load_and_authorize_resource)

  # Override ExceptionHandler for admin controllers to handle RecordNotFound properly
  rescue_from ActiveRecord::RecordNotFound do |e|
    respond_to do |format|
      format.html { redirect_to request.referer || root_path, alert: e.message }
      format.json { render json: { message: e.message }, status: :not_found }
    end
  end

  # Override CanCan authorization - make it public
  def authorize!(action, resource, *args)
    # Always allow for admin users
    if current_user&.admin? || current_user&.user_type == 'admin'
      return true
    end
    # Fall back to normal CanCan authorization
    super
  end

  # Override CanCan resource loading
  def load_and_authorize_resource
    # Skip for admin users
    return true if current_user&.admin? || current_user&.user_type == 'admin'
    super
  end

  private

  def ensure_admin
    unless current_user&.admin? || current_user&.user_type == 'admin'
      redirect_to root_path, alert: 'Access denied. Admin privileges required.'
    end
  end
end