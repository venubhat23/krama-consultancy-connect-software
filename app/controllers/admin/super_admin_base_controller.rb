class Admin::SuperAdminBaseController < Admin::ApplicationController
  before_action :ensure_super_admin

  private

  def ensure_super_admin
    unless current_user&.super_admin?
      redirect_to admin_customers_path, alert: 'Access denied. Super admin privileges required.'
    end
  end
end
