class Admin::Settings::BaseController < Admin::ApplicationController
  before_action :ensure_admin_access

  private

  def ensure_admin_access
    unless current_user&.admin? || current_user&.super_admin?
      redirect_to root_path, alert: 'Access denied. Settings management requires admin privileges.'
    end
  end
end