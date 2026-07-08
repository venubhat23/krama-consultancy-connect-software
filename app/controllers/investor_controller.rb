class InvestorController < ApplicationController
  include CurrencyHelper

  skip_load_and_authorize_resource
  before_action :authenticate_user!
  before_action :ensure_investor_user
  before_action :setup_investor_data

  def dashboard
    # Redirect to profit summary since we're removing the dashboard
    redirect_to investor_profit_summary_path
  end

  def profit_summary
    # Get company-wide statistics for context
    @total_commission_pool = CommissionPayout.where(payout_to: 'investor').sum(:payout_amount) || 0
    @total_shares = Investor.where.not(number_of_shares: nil).where('number_of_shares > 0').sum(:number_of_shares) || 0
    @profit_per_share = @total_shares > 0 ? @total_commission_pool / @total_shares : 0
    @system_investment_amount = SystemSetting.investment_amount || 0

    # Calculate this investor's specific profit data
    shares = @investor.number_of_shares || 0
    invested_amount = @investor.invested_amount || 0
    sharing_percentage = @investor.investment_percentage || 0

    # Calculate profit amounts for this investor
    profit_amount = shares * @profit_per_share
    actual_profit_shared_percentage = @investor.investment_percentage || 0
    actual_profit_shared = profit_amount * (actual_profit_shared_percentage / 100)
    roi = invested_amount > 0 ? (actual_profit_shared / invested_amount * 100) : 0

    # Store investor-specific data
    @investor_profit_data = {
      sl_no: 1,
      investor: @investor,
      shares: shares,
      invested_amount: invested_amount,
      sharing_percentage: sharing_percentage,
      profit_amount: profit_amount,
      actual_profit_shared_percentage: actual_profit_shared_percentage,
      actual_profit_shared: actual_profit_shared,
      roi: roi
    }
  end

  private

  def setup_investor_data
    @investor_user = current_user
    @investor = Investor.find_by(email: @investor_user.email) ||
                Investor.find_by(mobile: @investor_user.mobile)

    if @investor.nil?
      redirect_to root_path, alert: 'Investor profile not found.'
      return
    end
  end

  def ensure_investor_user
    unless current_user&.investor?
      redirect_to root_path, alert: 'Access denied. Investor access required.'
    end
  end

  def calculate_company_stats
    # Get all payouts to calculate company-wide statistics
    all_payouts = Payout.all

    # Calculate total premium collected
    total_premium_collected = all_payouts.sum(:total_premium).to_f

    # Calculate company expenses (from company_expenses field in payouts)
    total_company_expenses = all_payouts.sum(:company_expenses).to_f

    # Calculate total profit
    total_profit = all_payouts.sum(:profit).to_f

    # Calculate total investor commission
    total_investor_commission = CommissionPayout.where(payout_to: 'investor').sum(:payout_amount).to_f

    # Calculate profit margin percentage
    profit_margin = total_premium_collected > 0 ? ((total_profit / total_premium_collected) * 100).round(2) : 0

    # Calculate expense ratio
    expense_ratio = total_premium_collected > 0 ? ((total_company_expenses / total_premium_collected) * 100).round(2) : 0

    # Calculate monthly profit (last month)
    last_month_payouts = all_payouts.where(created_at: 1.month.ago.beginning_of_month..1.month.ago.end_of_month)
    last_month_profit = last_month_payouts.sum(:profit).to_f

    # Calculate current month profit
    current_month_payouts = all_payouts.where(created_at: Date.current.beginning_of_month..Date.current.end_of_month)
    current_month_profit = current_month_payouts.sum(:profit).to_f

    # Net profit after investor payouts
    net_profit = total_profit - total_investor_commission

    {
      total_premium_collected: total_premium_collected,
      total_company_expenses: total_company_expenses,
      total_profit: total_profit,
      total_investor_commission: total_investor_commission,
      profit_margin: profit_margin,
      expense_ratio: expense_ratio,
      last_month_profit: last_month_profit,
      current_month_profit: current_month_profit,
      net_profit: net_profit
    }
  end

  def calculate_investor_portion
    # Get this investor's policies
    health_policies = HealthInsurance.where(investor_id: @investor.id)
    motor_policies = MotorInsurance.where(investor_id: @investor.id)
    life_policies = LifeInsurance.where(investor_id: @investor.id) rescue []
    other_policies = OtherInsurance.where(investor_id: @investor.id) rescue []

    # Get all policy IDs for this investor
    all_policy_ids = {
      health: health_policies.pluck(:id),
      motor: motor_policies.pluck(:id),
      life: life_policies.pluck(:id),
      other: other_policies.pluck(:id)
    }

    # Calculate investor's total commission
    investor_commission = 0
    investor_commission += CommissionPayout.where(
      policy_type: 'health',
      policy_id: all_policy_ids[:health],
      payout_to: 'investor'
    ).sum(:payout_amount).to_f

    investor_commission += CommissionPayout.where(
      policy_type: 'motor',
      policy_id: all_policy_ids[:motor],
      payout_to: 'investor'
    ).sum(:payout_amount).to_f

    investor_commission += CommissionPayout.where(
      policy_type: 'life',
      policy_id: all_policy_ids[:life],
      payout_to: 'investor'
    ).sum(:payout_amount).to_f rescue 0

    investor_commission += CommissionPayout.where(
      policy_type: 'other',
      policy_id: all_policy_ids[:other],
      payout_to: 'investor'
    ).sum(:payout_amount).to_f rescue 0

    # Calculate paid and pending amounts
    paid_amount = CommissionPayout.where(
      policy_type: ['health', 'life', 'motor', 'other'],
      policy_id: all_policy_ids.values.flatten,
      payout_to: 'investor',
      status: 'paid'
    ).sum(:payout_amount).to_f

    pending_amount = CommissionPayout.where(
      policy_type: ['health', 'life', 'motor', 'other'],
      policy_id: all_policy_ids.values.flatten,
      payout_to: 'investor',
      status: 'pending'
    ).sum(:payout_amount).to_f

    # Calculate investor's share percentage of total investor commission
    total_investor_commission = CommissionPayout.where(payout_to: 'investor').sum(:payout_amount).to_f
    share_percentage = total_investor_commission > 0 ? ((investor_commission / total_investor_commission) * 100).round(2) : 0

    {
      total_commission: investor_commission,
      paid_amount: paid_amount,
      pending_amount: pending_amount,
      share_percentage: share_percentage,
      total_policies: health_policies.count + motor_policies.count + life_policies.count + other_policies.count
    }
  end

  def get_recent_commission_activity
    activities = []

    # Get recent investor commission payouts
    recent_payouts = CommissionPayout.where(payout_to: 'investor')
                                    .joins("LEFT JOIN health_insurances ON commission_payouts.policy_type = 'health' AND commission_payouts.policy_id = health_insurances.id")
                                    .joins("LEFT JOIN motor_insurances ON commission_payouts.policy_type = 'motor' AND commission_payouts.policy_id = motor_insurances.id")
                                    .where("health_insurances.investor_id = :id OR motor_insurances.investor_id = :id", id: @investor.id)
                                    .order(created_at: :desc)
                                    .limit(10)

    recent_payouts.each do |payout|
      policy = nil
      case payout.policy_type
      when 'health'
        policy = HealthInsurance.find_by(id: payout.policy_id)
        type = 'Health Insurance'
      when 'life'
        policy = LifeInsurance.find_by(id: payout.policy_id) rescue nil
        type = 'Life Insurance'
      when 'motor'
        policy = MotorInsurance.find_by(id: payout.policy_id)
        type = 'Motor Insurance'
      when 'other'
        policy = OtherInsurance.find_by(id: payout.policy_id) rescue nil
        type = 'Other Insurance'
      end

      next unless policy

      activities << {
        type: type,
        policy_number: policy.policy_number,
        amount: payout.payout_amount,
        date: payout.payout_date || payout.created_at,
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

      # Get policies for this month
      health_policies = HealthInsurance.where(investor_id: @investor.id)
                                      .where(created_at: month.beginning_of_month..month.end_of_month)
      life_policies = LifeInsurance.where(investor_id: @investor.id)
                                  .where(created_at: month.beginning_of_month..month.end_of_month) rescue []
      motor_policies = MotorInsurance.where(investor_id: @investor.id)
                                    .where(created_at: month.beginning_of_month..month.end_of_month)

      # Calculate commission for each type
      monthly_commission += CommissionPayout.where(
        policy_type: 'health',
        policy_id: health_policies.pluck(:id),
        payout_to: 'investor'
      ).sum(:payout_amount).to_f

      monthly_commission += CommissionPayout.where(
        policy_type: 'life',
        policy_id: life_policies.pluck(:id),
        payout_to: 'investor'
      ).sum(:payout_amount).to_f rescue 0

      monthly_commission += CommissionPayout.where(
        policy_type: 'motor',
        policy_id: motor_policies.pluck(:id),
        payout_to: 'investor'
      ).sum(:payout_amount).to_f

      trends[month_key] = {
        month: month.strftime("%B %Y"),
        commission: monthly_commission,
        policies_count: health_policies.count + life_policies.count + motor_policies.count
      }
    end

    trends.sort_by { |k, v| k }.reverse.to_h
  end

  def get_investment_summary
    # Returns a detailed breakdown of investments by category
    {
      health: {
        count: HealthInsurance.where(investor_id: @investor.id).count,
        total: HealthInsurance.where(investor_id: @investor.id).sum(:total_premium).to_f,
        commission: CommissionPayout.where(
          policy_type: 'health',
          policy_id: HealthInsurance.where(investor_id: @investor.id).pluck(:id),
          payout_to: 'investor'
        ).sum(:payout_amount).to_f
      },
      life: {
        count: (LifeInsurance.where(investor_id: @investor.id).count rescue 0),
        total: (LifeInsurance.where(investor_id: @investor.id).sum(:total_premium).to_f rescue 0),
        commission: (CommissionPayout.where(
          policy_type: 'life',
          policy_id: LifeInsurance.where(investor_id: @investor.id).pluck(:id),
          payout_to: 'investor'
        ).sum(:payout_amount).to_f rescue 0)
      },
      motor: {
        count: MotorInsurance.where(investor_id: @investor.id).count,
        total: MotorInsurance.where(investor_id: @investor.id).sum(:total_premium).to_f,
        commission: CommissionPayout.where(
          policy_type: 'motor',
          policy_id: MotorInsurance.where(investor_id: @investor.id).pluck(:id),
          payout_to: 'investor'
        ).sum(:payout_amount).to_f
      },
      other: {
        count: (OtherInsurance.where(investor_id: @investor.id).count rescue 0),
        total: (OtherInsurance.where(investor_id: @investor.id).sum(:total_premium).to_f rescue 0),
        commission: (CommissionPayout.where(
          policy_type: 'other',
          policy_id: OtherInsurance.where(investor_id: @investor.id).pluck(:id),
          payout_to: 'investor'
        ).sum(:payout_amount).to_f rescue 0)
      }
    }
  end

  def calculate_revenue_stats
    # Calculate quarterly revenue for this year
    current_year = Date.current.year
    quarters = {}

    (1..4).each do |quarter|
      quarter_start = Date.new(current_year, (quarter-1)*3 + 1, 1)
      quarter_end = quarter_start + 3.months - 1.day

      # Get revenue for this quarter
      quarterly_revenue = Payout.where(created_at: quarter_start..quarter_end)
                               .sum(:total_premium).to_f

      # Get investor commission for this quarter
      quarterly_investor_commission = CommissionPayout.where(
        created_at: quarter_start..quarter_end,
        payout_to: 'investor'
      ).sum(:payout_amount).to_f

      quarters["Q#{quarter}"] = {
        revenue: quarterly_revenue,
        investor_commission: quarterly_investor_commission,
        profit_margin: quarterly_revenue > 0 ? ((quarterly_investor_commission / quarterly_revenue) * 100).round(2) : 0
      }
    end

    # Calculate annual metrics
    total_annual_revenue = Payout.where(created_at: Date.current.beginning_of_year..Date.current.end_of_year)
                                .sum(:total_premium).to_f

    total_annual_investor_commission = CommissionPayout.where(
      created_at: Date.current.beginning_of_year..Date.current.end_of_year,
      payout_to: 'investor'
    ).sum(:payout_amount).to_f

    {
      quarterly_data: quarters,
      annual_revenue: total_annual_revenue,
      annual_investor_commission: total_annual_investor_commission,
      annual_investor_percentage: total_annual_revenue > 0 ? ((total_annual_investor_commission / total_annual_revenue) * 100).round(2) : 0,
      average_quarterly_revenue: total_annual_revenue / 4.0,
      revenue_per_policy: calculate_revenue_per_policy
    }
  end

  def calculate_growth_metrics
    current_month = Date.current.beginning_of_month..Date.current.end_of_month
    last_month = 1.month.ago.beginning_of_month..1.month.ago.end_of_month
    last_year_same_month = 1.year.ago.beginning_of_month..1.year.ago.end_of_month

    # Current month metrics
    current_month_revenue = Payout.where(created_at: current_month).sum(:total_premium).to_f
    current_month_policies = Payout.where(created_at: current_month).count

    # Last month metrics
    last_month_revenue = Payout.where(created_at: last_month).sum(:total_premium).to_f
    last_month_policies = Payout.where(created_at: last_month).count

    # Year over year metrics
    last_year_revenue = Payout.where(created_at: last_year_same_month).sum(:total_premium).to_f
    last_year_policies = Payout.where(created_at: last_year_same_month).count

    # Calculate growth percentages
    month_over_month_revenue = last_month_revenue > 0 ?
      (((current_month_revenue - last_month_revenue) / last_month_revenue) * 100).round(2) : 0

    year_over_year_revenue = last_year_revenue > 0 ?
      (((current_month_revenue - last_year_revenue) / last_year_revenue) * 100).round(2) : 0

    month_over_month_policies = last_month_policies > 0 ?
      (((current_month_policies - last_month_policies).to_f / last_month_policies) * 100).round(2) : 0

    {
      current_month_revenue: current_month_revenue,
      last_month_revenue: last_month_revenue,
      month_over_month_growth: month_over_month_revenue,
      year_over_year_growth: year_over_year_revenue,
      policy_growth_mom: month_over_month_policies,
      current_month_policies: current_month_policies,
      market_share: calculate_market_share
    }
  end

  def calculate_revenue_per_policy
    total_policies = Payout.where(created_at: Date.current.beginning_of_year..Date.current.end_of_year).count
    total_revenue = Payout.where(created_at: Date.current.beginning_of_year..Date.current.end_of_year)
                          .sum(:total_premium).to_f

    total_policies > 0 ? (total_revenue / total_policies).round(2) : 0
  end

  def calculate_market_share
    # This is a simplified calculation - you can enhance based on your market data
    total_company_policies = Payout.count
    industry_estimate = total_company_policies * 50 # Assuming company has ~2% market share

    industry_estimate > 0 ? ((total_company_policies.to_f / industry_estimate) * 100).round(2) : 0
  end

  def calculate_detailed_profit_breakdown
    # Get all DrWise policies where this investor is involved
    investor_policies = get_investor_policies

    total_premium = 0
    total_commission = 0
    total_company_expenses = 0
    total_investor_commission = 0

    breakdown = {}

    # Process each policy type
    ['health', 'life', 'motor', 'other'].each do |policy_type|
      policies = investor_policies[policy_type.to_sym] || []

      type_premium = policies.sum { |p| p.total_premium.to_f }
      type_company_expenses = policies.sum { |p| p.try(:company_expenses).to_f || (p.total_premium.to_f * 0.05) }

      # Get investor commission for these policies
      type_investor_commission = CommissionPayout.where(
        policy_type: policy_type,
        policy_id: policies.pluck(:id),
        payout_to: 'investor'
      ).sum(:payout_amount).to_f

      # For investors: profit = commission only
      type_profit = type_investor_commission

      breakdown[policy_type.to_sym] = {
        policies_count: policies.count,
        total_premium: type_premium,
        company_expenses: type_company_expenses,
        investor_commission: type_investor_commission,
        profit: type_profit,
        profit_margin: type_premium > 0 ? ((type_profit / type_premium) * 100).round(2) : 0
      }

      total_premium += type_premium
      total_commission += type_investor_commission
      total_company_expenses += type_company_expenses
    end

    breakdown[:overall] = {
      total_premium: total_premium,
      total_company_expenses: total_company_expenses,
      total_investor_commission: total_commission,
      total_profit: total_commission,
      profit_margin: total_premium > 0 ? ((total_commission / total_premium) * 100).round(2) : 0
    }

    breakdown
  end

  def calculate_policy_wise_profits
    investor_policies = get_investor_policies
    policy_profits = []

    # Process each policy individually
    ['health', 'life', 'motor', 'other'].each do |policy_type|
      policies = investor_policies[policy_type.to_sym] || []

      policies.each do |policy|
        premium = policy.total_premium.to_f
        company_expenses = policy.try(:company_expenses).to_f || (premium * 0.05)

        # Get specific investor commission for this policy
        investor_commission = CommissionPayout.where(
          policy_type: policy_type,
          policy_id: policy.id,
          payout_to: 'investor'
        ).sum(:payout_amount).to_f

        # For investors: profit = commission only
        profit = investor_commission

        policy_profits << {
          policy_type: policy_type.capitalize,
          policy_number: policy.policy_number,
          customer_name: policy.customer&.display_name || 'N/A',
          policy_date: policy.created_at,
          premium: premium,
          company_expenses: company_expenses,
          investor_commission: investor_commission,
          profit: profit,
          profit_margin: premium > 0 ? ((profit / premium) * 100).round(2) : 0,
          status: policy.try(:status) || 'Active'
        }
      end
    end

    # Sort by profit descending
    policy_profits.sort_by { |p| -p[:profit] }
  end

  def calculate_monthly_profit_trends
    trends = {}

    (0..11).each do |months_ago|
      month_start = months_ago.months.ago.beginning_of_month
      month_end = months_ago.months.ago.end_of_month
      month_key = month_start.strftime("%Y-%m")

      # Get policies created in this month for this investor
      monthly_policies = get_investor_policies_for_period(month_start, month_end)

      monthly_premium = 0
      monthly_expenses = 0
      monthly_investor_commission = 0

      ['health', 'life', 'motor', 'other'].each do |policy_type|
        policies = monthly_policies[policy_type.to_sym] || []

        type_premium = policies.sum { |p| p.total_premium.to_f }
        type_expenses = policies.sum { |p| p.try(:company_expenses).to_f || (p.total_premium.to_f * 0.05) }
        type_commission = CommissionPayout.where(
          policy_type: policy_type,
          policy_id: policies.pluck(:id),
          payout_to: 'investor'
        ).sum(:payout_amount).to_f

        monthly_premium += type_premium
        monthly_expenses += type_expenses
        monthly_investor_commission += type_commission
      end

      # For investors: profit = commission only
      monthly_profit = monthly_investor_commission

      trends[month_key] = {
        month: month_start.strftime("%B %Y"),
        premium: monthly_premium,
        expenses: monthly_expenses,
        investor_commission: monthly_investor_commission,
        profit: monthly_profit,
        policies_count: monthly_policies.values.flatten.count
      }
    end

    trends.sort_by { |k, v| k }.reverse.to_h
  end

  def calculate_total_profit_stats
    all_policies = get_investor_policies
    total_policies_count = all_policies.values.flatten.count

    total_premium = all_policies.values.flatten.sum { |p| p.total_premium.to_f }
    total_expenses = all_policies.values.flatten.sum { |p| p.try(:company_expenses).to_f || (p.total_premium.to_f * 0.05) }

    total_investor_commission = CommissionPayout.where(
      policy_type: ['health', 'life', 'motor', 'other'],
      policy_id: all_policies.values.flatten.pluck(:id),
      payout_to: 'investor'
    ).sum(:payout_amount).to_f

    # For investors: profit = commission only
    total_profit = total_investor_commission

    {
      total_policies: total_policies_count,
      total_premium: total_premium,
      total_expenses: total_expenses,
      total_investor_commission: total_investor_commission,
      total_profit: total_profit,
      average_profit_per_policy: total_policies_count > 0 ? (total_profit / total_policies_count).round(2) : 0,
      profit_margin: total_premium > 0 ? ((total_profit / total_premium) * 100).round(2) : 0
    }
  end

  def get_investor_policies
    # For life and other insurance, we need to find policies through commission payouts
    # since these tables don't have investor_id columns

    life_policy_ids = CommissionPayout.where(
      policy_type: 'life',
      payout_to: 'investor'
    ).where(
      'payout_amount > 0'
    ).pluck(:policy_id).uniq

    other_policy_ids = CommissionPayout.where(
      policy_type: 'other',
      payout_to: 'investor'
    ).where(
      'payout_amount > 0'
    ).pluck(:policy_id).uniq

    {
      health: HealthInsurance.where(investor_id: @investor.id),
      life: LifeInsurance.where(id: life_policy_ids),
      motor: MotorInsurance.where(investor_id: @investor.id),
      other: OtherInsurance.where(id: other_policy_ids)
    }
  end

  def get_investor_policies_for_period(start_date, end_date)
    # For life and other insurance, we need to find policies through commission payouts
    # since these tables don't have investor_id columns

    life_policy_ids = CommissionPayout.where(
      policy_type: 'life',
      payout_to: 'investor',
      created_at: start_date..end_date
    ).where(
      'payout_amount > 0'
    ).pluck(:policy_id).uniq

    other_policy_ids = CommissionPayout.where(
      policy_type: 'other',
      payout_to: 'investor',
      created_at: start_date..end_date
    ).where(
      'payout_amount > 0'
    ).pluck(:policy_id).uniq

    {
      health: HealthInsurance.where(investor_id: @investor.id, created_at: start_date..end_date),
      life: LifeInsurance.where(id: life_policy_ids, created_at: start_date..end_date),
      motor: MotorInsurance.where(investor_id: @investor.id, created_at: start_date..end_date),
      other: OtherInsurance.where(id: other_policy_ids, created_at: start_date..end_date)
    }
  end
end