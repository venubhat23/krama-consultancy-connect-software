class Admin::Settings::SystemController < Admin::Settings::BaseController

  def index
    @company_expenses_percentage = SystemSetting.company_expenses_percentage
    @default_pagination_per_page = SystemSetting.default_pagination_per_page
    @default_main_agent_commission = SystemSetting.default_main_agent_commission
    @default_affiliate_commission = SystemSetting.default_affiliate_commission
    @default_ambassador_commission = SystemSetting.default_ambassador_commission
    @default_company_expenses = SystemSetting.default_company_expenses
    @terms_and_conditions = SystemSetting.terms_and_conditions
    @investment_amount = SystemSetting.investment_amount
    @company_info = SystemSetting.company_info
    @default_business_plan_key = SystemSetting.default_business_plan_key

    @system_settings = {
      app_name: 'InsureBook Admin',
      version: '1.0.0',
      maintenance_mode: false,
      email_notifications: true,
      backup_frequency: 'Daily',
      session_timeout: 60
    }
  end

  def update
    success_messages = []

    # Handle company expenses percentage
    if params[:company_expenses_percentage].present?
      percentage = params[:company_expenses_percentage].to_f

      # Validate percentage (should be between 0 and 100)
      if percentage >= 0 && percentage <= 100
        SystemSetting.set_company_expenses_percentage(percentage)
        success_messages << 'Company expenses percentage updated successfully!'
      else
        redirect_to admin_settings_system_path, alert: 'Invalid percentage. Please enter a value between 0 and 100.'
        return
      end
    end

    # Handle default pagination per page
    if params[:default_pagination_per_page].present?
      per_page = params[:default_pagination_per_page].to_i

      # Validate per_page (should be between 5 and 100)
      if per_page >= 5 && per_page <= 100
        SystemSetting.set_default_pagination_per_page(per_page)
        success_messages << 'Default pagination per page updated successfully!'
      else
        redirect_to admin_settings_system_path, alert: 'Invalid pagination value. Please enter a value between 5 and 100.'
        return
      end
    end

    # Handle default business plan for new forums
    if params[:default_business_plan_key].present?
      if BusinessPlan.exists?(key: params[:default_business_plan_key])
        SystemSetting.set_default_business_plan_key(params[:default_business_plan_key])
        success_messages << 'Default business plan updated successfully!'
      else
        redirect_to admin_settings_system_path, alert: 'Unknown business plan selected.'
        return
      end
    end

    # Handle commission settings update
    if params[:commission_settings_update] == "true"
      commission_params = {
        default_main_agent_commission: params[:default_main_agent_commission]&.to_f,
        default_affiliate_commission: params[:default_affiliate_commission]&.to_f,
        default_ambassador_commission: params[:default_ambassador_commission]&.to_f,
        default_company_expenses: params[:default_company_expenses]&.to_f
      }

      # Validate all commission values
      valid_commissions = commission_params.values.all? do |value|
        value && value >= 0 && value <= 100
      end

      if valid_commissions
        begin
          SystemSetting.update_commission_settings(commission_params)
          success_messages << 'Commission settings updated successfully!'
        rescue => e
          redirect_to admin_settings_system_path, alert: "Error updating commission settings: #{e.message}"
          return
        end
      else
        redirect_to admin_settings_system_path, alert: 'Invalid commission values. Please enter percentages between 0 and 100.'
        return
      end
    end

    # Handle terms and conditions update
    if params[:terms_and_conditions_update] == "true"
      terms_content = params[:terms_and_conditions]&.strip

      if terms_content.present?
        begin
          SystemSetting.set_terms_and_conditions(terms_content)
          success_messages << 'Terms and conditions updated successfully!'
        rescue => e
          redirect_to admin_settings_system_path, alert: "Error updating terms and conditions: #{e.message}"
          return
        end
      else
        redirect_to admin_settings_system_path, alert: 'Terms and conditions cannot be empty.'
        return
      end
    end

    # Handle investment amount update
    if params[:investment_amount_update] == "true"
      amount = params[:investment_amount]&.to_f

      if amount.present? && amount >= 0
        begin
          SystemSetting.set_investment_amount(amount)
          success_messages << 'Investment amount updated successfully!'
        rescue => e
          redirect_to admin_settings_system_path, alert: "Error updating investment amount: #{e.message}"
          return
        end
      else
        redirect_to admin_settings_system_path, alert: 'Please enter a valid investment amount (must be 0 or greater).'
        return
      end
    end

    # Handle company info update
    if params[:company_info_update] == "true"
      begin
        SystemSetting.update_company_info(
          company_name:    params[:company_name],
          company_mobile:  params[:company_mobile],
          company_email:   params[:company_email],
          company_address: params[:company_address],
          company_website: params[:company_website],
          support_hours:   params[:support_hours]
        )
        success_messages << 'Company information updated successfully!'
      rescue => e
        redirect_to admin_settings_system_path, alert: "Error updating company info: #{e.message}"
        return
      end
    end

    if success_messages.any?
      redirect_to admin_settings_system_path, notice: success_messages.join(' ')
    else
      redirect_to admin_settings_system_path, alert: 'Please enter valid values to update.'
    end
  end

  private

  def system_setting_params
    params.require(:system_setting).permit(
      :maintenance_mode, :email_notifications, :backup_frequency, :session_timeout,
      :max_file_upload_size, :company_expenses_percentage, :default_pagination_per_page,
      :default_main_agent_commission, :default_affiliate_commission,
      :default_ambassador_commission, :default_company_expenses, :terms_and_conditions,
      :investment_amount
    )
  end
end