class Admin::ReportsController < Admin::ApplicationController

  # Explicitly skip CanCan for this controller
  skip_authorization_check if respond_to?(:skip_authorization_check)
  skip_load_and_authorize_resource if respond_to?(:skip_load_and_authorize_resource)

  # GET /admin/reports/commission
  def commission
    @date_range = params[:date_range] || '30_days'

    case @date_range
    when '7_days'
      start_date = 7.days.ago
    when '30_days'
      start_date = 30.days.ago
    when '3_months'
      start_date = 3.months.ago
    when '6_months'
      start_date = 6.months.ago
    when '1_year'
      start_date = 1.year.ago
    else
      start_date = 30.days.ago
    end

    # Commission calculations would go here
    # This is a placeholder implementation
    @total_commission = Policy.where(created_at: start_date..Time.current).sum(:total_premium) * 0.1 rescue 0
    @commission_by_agent = User.where(user_type: ['agent', 'sub_agent'])
                               .joins(:policies)
                               .where(policies: { created_at: start_date..Time.current })
                               .group('users.first_name', 'users.last_name')
                               .sum('policies.total_premium * 0.1') rescue {}
  end

  # GET /admin/reports/expired_insurance
  def expired_insurance
    @expired_health_insurances = HealthInsurance.expired.includes(:customer).order(:policy_end_date)
    @expired_life_insurances = LifeInsurance.expired.includes(:customer).order(:policy_end_date)
    @expired_motor_insurances = MotorInsurance.expired.includes(policy: :customer).order(:policy_end_date)
    @expired_other_insurances = OtherInsurance.expired.includes(policy: :customer).order(:policy_end_date)

    @stats = {
      total_expired: @expired_health_insurances.count + @expired_life_insurances.count +
                    @expired_motor_insurances.count + @expired_other_insurances.count,
      health_expired: @expired_health_insurances.count,
      life_expired: @expired_life_insurances.count,
      motor_expired: @expired_motor_insurances.count,
      other_expired: @expired_other_insurances.count
    }
  rescue => e
    Rails.logger.error "Error in expired_insurance: #{e.message}"
    @expired_health_insurances = HealthInsurance.none
    @expired_life_insurances = LifeInsurance.none
    @expired_motor_insurances = MotorInsurance.none
    @expired_other_insurances = OtherInsurance.none
    @stats = {
      total_expired: 0,
      health_expired: 0,
      life_expired: 0,
      motor_expired: 0,
      other_expired: 0
    }
  end

  # GET /admin/reports/payment_due
  def payment_due
    # Logic for payment due reports
    @payment_due_policies = Policy.active
                                  .where('end_date > ? AND end_date <= ?', Date.current, 30.days.from_now)
                                  .includes(:customer)
                                  .order(:end_date) rescue []
  end

  # GET /admin/reports/upcoming_renewal
  def upcoming_renewal
    # Define renewal period (next 60 days)
    start_date = Date.current
    end_date = 60.days.from_now

    @renewal_health_insurances = HealthInsurance.where(policy_end_date: start_date..end_date)
                                               .includes(:customer)
                                               .order(:policy_end_date)

    @renewal_life_insurances = LifeInsurance.where(policy_end_date: start_date..end_date)
                                           .includes(:customer)
                                           .order(:policy_end_date)

    @renewal_motor_insurances = MotorInsurance.where(policy_end_date: start_date..end_date)
                                             .includes(policy: :customer)
                                             .order(:policy_end_date)

    @renewal_other_insurances = OtherInsurance.where(policy_end_date: start_date..end_date)
                                             .includes(policy: :customer)
                                             .order(:policy_end_date)

    @stats = {
      total_renewals: @renewal_health_insurances.count + @renewal_life_insurances.count +
                     @renewal_motor_insurances.count + @renewal_other_insurances.count,
      health_renewals: @renewal_health_insurances.count,
      life_renewals: @renewal_life_insurances.count,
      motor_renewals: @renewal_motor_insurances.count,
      other_renewals: @renewal_other_insurances.count
    }
  rescue => e
    Rails.logger.error "Error in upcoming_renewal: #{e.message}"
    @renewal_health_insurances = HealthInsurance.none
    @renewal_life_insurances = LifeInsurance.none
    @renewal_motor_insurances = MotorInsurance.none
    @renewal_other_insurances = OtherInsurance.none
    @stats = {
      total_renewals: 0,
      health_renewals: 0,
      life_renewals: 0,
      motor_renewals: 0,
      other_renewals: 0
    }
  end

  # GET /admin/reports/upcoming_payment
  def upcoming_payment
    @upcoming_payments = Policy.active
                               .where('end_date BETWEEN ? AND ?', Date.current, 30.days.from_now)
                               .includes(:customer)
                               .order(:end_date) rescue []
  end

  # GET /admin/reports/leads
  def leads
    @date_range = params[:date_range] || '30_days'

    case @date_range
    when '7_days'
      start_date = 7.days.ago
    when '30_days'
      start_date = 30.days.ago
    when '3_months'
      start_date = 3.months.ago
    when '6_months'
      start_date = 6.months.ago
    when '1_year'
      start_date = 1.year.ago
    else
      start_date = 30.days.ago
    end

    @leads_data = {
      total_leads: Lead.where(created_date: start_date..Time.current).count,
      conversion_rate: 0
    }

    if Lead.column_names.include?('current_stage')
      @leads_by_stage = Lead.where(created_date: start_date..Time.current)
                           .group(:current_stage)
                           .count
    else
      @leads_by_stage = {}
    end
  rescue
    @leads_data = { total_leads: 0, conversion_rate: 0 }
    @leads_by_stage = {}
  end

  # GET /admin/reports/sessions - commented out (NPE)
  # def sessions
  #   @date_range = params[:date_range] || 'today'
  #
  #   case @date_range
  #   when 'today'
  #     start_date = Date.current.beginning_of_day
  #     end_date = Date.current.end_of_day
  #   when '7_days'
  #     start_date = 7.days.ago.beginning_of_day
  #     end_date = Date.current.end_of_day
  #   when '30_days'
  #     start_date = 30.days.ago.beginning_of_day
  #     end_date = Date.current.end_of_day
  #   when '3_months'
  #     start_date = 3.months.ago.beginning_of_day
  #     end_date = Date.current.end_of_day
  #   else
  #     start_date = Date.current.beginning_of_day
  #     end_date = Date.current.end_of_day
  #   end
  #
  #   @active_users = User.where(status: true).count
  #   @total_sessions = User.where(created_at: start_date..end_date).count
  #   @avg_session_time = "24m"
  #   @failed_logins = 0
  #
  #   @recent_sessions = User.where(status: true)
  #                         .limit(20)
  #                         .order(created_at: :desc)
  #                         .map.with_index do |user, index|
  #     {
  #       id: user.id,
  #       user_id: user.id,
  #       user_name: "#{user.first_name} #{user.last_name}".strip,
  #       email: user.email,
  #       user_type: user.user_type || 'user',
  #       login_time: user.created_at + rand(0..72).hours,
  #       last_activity: case rand(5)
  #                     when 0 then "Just now"
  #                     when 1 then "#{rand(1..10)} minutes ago"
  #                     when 2 then "#{rand(1..2)} hours ago"
  #                     else "#{rand(1..5)} hours ago"
  #                     end,
  #       duration: "#{rand(5..120)}m",
  #       ip_address: "192.168.1.#{rand(100..200)}",
  #       status: rand(10) < 7 ? 'active' : 'inactive'
  #     }
  #   end
  # end
end