class AmbassadorController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_ambassador_user
  before_action :setup_ambassador_data

  def dashboard
    # Common data setup handled by before_action

    # Recent commission activity
    @recent_commission_activity = get_recent_commission_activity

    # Monthly commission trends (last 6 months)
    @monthly_trends = get_monthly_commission_trends
  end

  def commission_details
    # Common data setup handled by before_action

    # Monthly commission trends (needed for the view)
    @monthly_trends = get_monthly_commission_trends

    # Recent commission activity
    @recent_commission_activity = get_recent_commission_activity

    # Get all commission data with filters
    @commission_data = get_filtered_commission_data

    # Pagination (safely handle if Kaminari is available)
    if @commission_data.respond_to?(:page)
      @commission_data = @commission_data.page(params[:page]).per(20)
    end
  end

  def payout_history
    # Common data setup handled by before_action

    # Get payout history
    @payouts = get_ambassador_payouts.order(created_at: :desc)

    # Pagination (safely handle if Kaminari is available)
    if @payouts.respond_to?(:page)
      @payouts = @payouts.page(params[:page]).per(15)
    end

    # Summary statistics
    @total_earned = @payouts.where(status: 'paid').sum(:payout_amount)
    @pending_amount = @payouts.where(status: 'pending').sum(:payout_amount)
    @total_policies = get_total_policies_count
  end

  private

  def setup_ambassador_data
    @ambassador = current_user
    @distributor = Distributor.find_by(email: @ambassador.email)

    if @distributor.nil?
      redirect_to root_path, alert: 'Ambassador profile not found.'
      return
    end

    # Get assigned affiliates with their detailed information
    @assigned_affiliates = @distributor.assigned_sub_agents.includes(
      :distributor_assignment
    ).order('sub_agents.created_at DESC')

    # Calculate statistics for each affiliate
    @affiliate_stats = {}
    @assigned_affiliates.each do |affiliate|
      @affiliate_stats[affiliate.id] = calculate_affiliate_stats(affiliate)
    end

    # Overall distributor statistics
    @distributor_stats = calculate_distributor_stats
  end

  def ensure_ambassador_user
    unless current_user&.ambassador?
      redirect_to root_path, alert: 'Access denied. Ambassador access required.'
    end
  end

  def calculate_affiliate_stats(affiliate)
    health_policies = HealthInsurance.where(sub_agent_id: affiliate.id)
    life_policies = LifeInsurance.where(sub_agent_id: affiliate.id)
    motor_policies = MotorInsurance.where(sub_agent_id: affiliate.id)

    # Safely try to get other policies if the association exists
    other_policies_count = 0
    other_policies_premium = 0.0
    other_policies_commission = 0.0

    begin
      # Try to get other insurance directly by sub_agent_id
      if defined?(OtherInsurance)
        other_policies = OtherInsurance.where(sub_agent_id: affiliate.id)
        other_policies_count = other_policies.count
        other_policies_premium = other_policies.sum(:total_premium).to_f rescue 0.0
        # Check if commission_amount column exists, otherwise calculate basic commission
        if other_policies.column_names.include?('commission_amount')
          other_policies_commission = other_policies.sum(:commission_amount).to_f rescue 0.0
        else
          other_policies_commission = (other_policies_premium * 0.05).to_f rescue 0.0
        end
      end
    rescue => e
      Rails.logger.debug "Could not load other insurance data: #{e.message}"
      other_policies_count = 0
      other_policies_premium = 0.0
      other_policies_commission = 0.0
    end

    total_policies = health_policies.count + life_policies.count + motor_policies.count + other_policies_count
    total_premium = (health_policies.sum(:total_premium) +
                    life_policies.sum(:total_premium) +
                    motor_policies.sum(:total_premium) +
                    other_policies_premium).to_f

    # Calculate ambassador commission from commission_payouts table
    health_commission = CommissionPayout.where(
      policy_type: 'health',
      policy_id: health_policies.pluck(:id),
      payout_to: 'ambassador'
    ).sum(:payout_amount).to_f

    life_commission = CommissionPayout.where(
      policy_type: 'life',
      policy_id: life_policies.pluck(:id),
      payout_to: 'ambassador'
    ).sum(:payout_amount).to_f

    motor_commission = CommissionPayout.where(
      policy_type: 'motor',
      policy_id: motor_policies.pluck(:id),
      payout_to: 'ambassador'
    ).sum(:payout_amount).to_f

    other_commission = 0.0
    if other_policies_count > 0
      begin
        other_policy_ids = OtherInsurance.where(sub_agent_id: affiliate.id).pluck(:id)
        other_commission = CommissionPayout.where(
          policy_type: 'other',
          policy_id: other_policy_ids,
          payout_to: 'ambassador'
        ).sum(:payout_amount).to_f
      rescue => e
        other_commission = 0.0
      end
    end

    total_commission = (health_commission + life_commission + motor_commission + other_commission).to_f

    # Get unique customers from all policies created by this affiliate
    customer_ids = []
    customer_ids += health_policies.pluck(:customer_id).compact
    customer_ids += life_policies.pluck(:customer_id).compact
    customer_ids += motor_policies.pluck(:customer_id).compact
    unique_customers_count = customer_ids.uniq.count

    {
      total_policies: total_policies,
      total_premium: total_premium,
      total_commission: total_commission,
      health_policies: health_policies.count,
      health_commission: health_commission,
      life_policies: life_policies.count,
      life_commission: life_commission,
      motor_policies: motor_policies.count,
      motor_commission: motor_commission,
      other_policies: other_policies_count,
      other_commission: other_commission,
      recent_policies: get_recent_policies_for_affiliate(affiliate),
      customers_count: unique_customers_count,
      joined_date: affiliate.created_at
    }
  end

  def calculate_distributor_stats
    total_policies = 0
    total_premium = 0.0
    total_commission = 0.0
    total_customers = 0

    @assigned_affiliates.each do |affiliate|
      stats = @affiliate_stats[affiliate.id]
      total_policies += stats[:total_policies]
      total_premium += stats[:total_premium]
      total_commission += stats[:total_commission]
      total_customers += stats[:customers_count]
    end

    {
      total_affiliates: @assigned_affiliates.count,
      active_affiliates: @assigned_affiliates.active.count,
      total_policies: total_policies,
      total_premium: total_premium,
      total_commission: total_commission,
      total_customers: total_customers,
      avg_policies_per_affiliate: @assigned_affiliates.count > 0 ? (total_policies.to_f / @assigned_affiliates.count).round(2) : 0
    }
  end

  def get_recent_policies_for_affiliate(affiliate)
    policies = []

    # Get recent health policies
    HealthInsurance.where(sub_agent_id: affiliate.id)
                   .includes(:customer)
                   .order(created_at: :desc)
                   .limit(3)
                   .each do |policy|
      policies << {
        type: 'Health',
        policy_number: policy.policy_number,
        customer: policy.customer&.display_name || 'Unknown',
        premium: policy.total_premium,
        commission: CommissionPayout.where(policy_type: 'health', policy_id: policy.id, payout_to: 'ambassador').sum(:payout_amount),
        created_at: policy.created_at
      }
    end

    # Get recent life policies
    LifeInsurance.where(sub_agent_id: affiliate.id)
                 .includes(:customer)
                 .order(created_at: :desc)
                 .limit(3)
                 .each do |policy|
      policies << {
        type: 'Life',
        policy_number: policy.policy_number,
        customer: policy.customer&.display_name || 'Unknown',
        premium: policy.total_premium,
        commission: CommissionPayout.where(policy_type: 'life', policy_id: policy.id, payout_to: 'ambassador').sum(:payout_amount),
        created_at: policy.created_at
      }
    end

    # Get recent motor policies
    MotorInsurance.where(sub_agent_id: affiliate.id)
                  .includes(:customer)
                  .order(created_at: :desc)
                  .limit(2)
                  .each do |policy|
      policies << {
        type: 'Motor',
        policy_number: policy.policy_number,
        customer: policy.customer&.display_name || 'Unknown',
        premium: policy.total_premium,
        commission: policy.main_agent_commission_amount || 0,
        created_at: policy.created_at
      }
    end

    # Sort by creation date and return top 5
    policies.sort_by { |p| p[:created_at] }.reverse.first(5)
  end

  def get_recent_commission_activity
    activities = []
    affiliate_ids = @assigned_affiliates.pluck(:id)

    # Get recent ambassador commission payouts for all policies handled by assigned affiliates
    recent_payouts = CommissionPayout.where(payout_to: 'ambassador')
                                    .order(payout_date: :desc, created_at: :desc)
                                    .limit(10)

    recent_payouts.each do |payout|
      policy = nil
      case payout.policy_type
      when 'health'
        policy = HealthInsurance.joins(:customer).find_by(id: payout.policy_id, sub_agent_id: affiliate_ids)
        type = 'Health Insurance Commission'
      when 'life'
        policy = LifeInsurance.joins(:customer).find_by(id: payout.policy_id, sub_agent_id: affiliate_ids)
        type = 'Life Insurance Commission'
      when 'motor'
        policy = MotorInsurance.joins(:customer).find_by(id: payout.policy_id, sub_agent_id: affiliate_ids)
        type = 'Motor Insurance Commission'
      end

      next unless policy

      activities << {
        type: type,
        description: "Commission from #{policy.customer.display_name}",
        amount: payout.payout_amount,
        policy_number: policy.policy_number,
        date: payout.payout_date || policy.created_at,
        status: payout.status
      }
    end

    activities
  end

  def get_monthly_commission_trends
    trends = {}
    6.times do |i|
      month = i.months.ago
      month_key = month.strftime("%Y-%m")

      monthly_commission = 0

      # Get health insurance policies for this month
      health_policies = HealthInsurance.where(sub_agent_id: @assigned_affiliates.pluck(:id))
                                      .where(created_at: month.beginning_of_month..month.end_of_month)

      # Calculate ambassador commission from commission payouts for health policies
      monthly_commission += CommissionPayout.where(
        policy_type: 'health',
        policy_id: health_policies.pluck(:id),
        payout_to: 'ambassador'
      ).sum(:payout_amount).to_f

      # Get life insurance policies for this month
      life_policies = LifeInsurance.where(sub_agent_id: @assigned_affiliates.pluck(:id))
                                  .where(created_at: month.beginning_of_month..month.end_of_month)

      # Calculate ambassador commission from commission payouts for life policies
      monthly_commission += CommissionPayout.where(
        policy_type: 'life',
        policy_id: life_policies.pluck(:id),
        payout_to: 'ambassador'
      ).sum(:payout_amount).to_f

      # Get motor insurance policies for this month
      motor_policies = MotorInsurance.where(sub_agent_id: @assigned_affiliates.pluck(:id))
                                    .where(created_at: month.beginning_of_month..month.end_of_month)

      # Calculate ambassador commission from commission payouts for motor policies
      monthly_commission += CommissionPayout.where(
        policy_type: 'motor',
        policy_id: motor_policies.pluck(:id),
        payout_to: 'ambassador'
      ).sum(:payout_amount).to_f

      trends[month_key] = {
        month: month.strftime("%B %Y"),
        commission: monthly_commission,
        policies_count: get_monthly_policies_count(month)
      }
    end

    trends.sort_by { |k, v| k }.reverse.to_h
  end

  def get_monthly_policies_count(month)
    health_count = HealthInsurance.where(sub_agent_id: @assigned_affiliates.pluck(:id))
                                 .where(created_at: month.beginning_of_month..month.end_of_month)
                                 .count

    life_count = LifeInsurance.where(sub_agent_id: @assigned_affiliates.pluck(:id))
                             .where(created_at: month.beginning_of_month..month.end_of_month)
                             .count

    motor_count = MotorInsurance.where(sub_agent_id: @assigned_affiliates.pluck(:id))
                               .where(created_at: month.beginning_of_month..month.end_of_month)
                               .count

    health_count + life_count + motor_count
  end

  def get_filtered_commission_data
    # This would contain detailed commission breakdown logic
    # For now, return empty relation
    Payout.none
  end

  def get_ambassador_payouts
    # Get payouts related to this ambassador/distributor
    if defined?(DistributorPayout)
      DistributorPayout.where(distributor_id: @distributor.id)
    else
      Payout.none
    end
  end

  def get_total_policies_count
    health_count = HealthInsurance.where(sub_agent_id: @assigned_affiliates.pluck(:id)).count
    life_count = LifeInsurance.where(sub_agent_id: @assigned_affiliates.pluck(:id)).count
    motor_count = MotorInsurance.where(sub_agent_id: @assigned_affiliates.pluck(:id)).count

    health_count + life_count + motor_count
  end
end