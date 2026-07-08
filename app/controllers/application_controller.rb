class ApplicationController < ActionController::Base
  # Protect from CSRF attacks
  protect_from_forgery with: :exception

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Include exception handler for API
  include ExceptionHandler

  # Include permissions helper for CRUD access control
  helper PermissionsHelper
  include PermissionsHelper

  # Devise authentication
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

  # Ahoy session tracking
  after_action :track_ahoy_visit

  # Use devise layout for devise controllers
  layout :layout_by_resource

  # Authorization
  load_and_authorize_resource unless: :devise_controller?, if: :should_authorize?

  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_path, alert: exception.message
  end

  # Redirect users after sign in based on their role
  def after_sign_in_path_for(resource)
    if resource.ambassador?
      ambassador_dashboard_path
    elsif resource.investor?
      investor_profit_summary_path
    elsif resource.super_admin?
      admin_platform_dashboard_path
    elsif resource.forum_admin? || resource.chapter_admin?
      forum_portal_dashboard_path
    elsif resource.member?
      member_portal_dashboard_path
    else
      stored_location_for(resource) || admin_customers_path
    end
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_in, keys: [:login])
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :mobile, :user_type, :role, :status])
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :mobile, :user_type, :role, :pan_number, :gst_number, :date_of_birth, :gender, :height, :weight, :education, :marital_status, :occupation, :job_name, :type_of_duty, :annual_income, :birth_place, :address, :state, :city])
  end

  def current_ability
    @current_ability ||= Ability.new(current_user)
  end

  def should_authorize?
    # Skip authorization for admin controllers if user is admin
    if self.class.name.start_with?('Admin::') && (current_user&.admin? || current_user&.user_type == 'admin')
      return false
    end

    # Skip authorization for ambassador controller
    if self.class.name == 'AmbassadorController'
      return false
    end

    # Skip authorization for investor controller
    if self.class.name == 'InvestorController'
      return false
    end

    # Skip authorization for the new forum-platform portals (role checks handle access instead)
    if self.class.name.start_with?('ForumPortal::', 'MemberPortal::')
      return false
    end

    true
  end

  private

  def layout_by_resource
    if devise_controller?
      "devise"
    else
      "application"
    end
  end

  def track_ahoy_visit
    # Track page views automatically
    if current_user
      ahoy.track "$view", page: request.path, controller: controller_name, action: action_name
    end
  rescue => e
    # Silently fail if Ahoy is not available
    Rails.logger.debug "Ahoy tracking failed: #{e.message}"
  end

  # Serve favicon.ico from public assets
  def favicon
    icon_path = Rails.public_path.join('icon.png')
    if File.exist?(icon_path)
      send_file icon_path, type: 'image/png', disposition: 'inline'
    else
      head :not_found
    end
  end
end
