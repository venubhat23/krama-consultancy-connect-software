class Admin::CommissionsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_distributor_access

  def dashboard
    @commission_stats = {
      total_earned: calculate_total_commission,
      this_month: calculate_monthly_commission,
      pending_amount: calculate_pending_commission,
      total_policies: count_total_policies
    }

    @recent_payouts = recent_commission_payouts.limit(5)
    @monthly_chart_data = monthly_commission_chart_data
  end

  def reports
    @date_range = params[:date_range] || 'this_month'
    @policy_type = params[:policy_type] || 'all'

    @commission_reports = commission_reports_data
    @commission_breakdown = commission_breakdown_data
  end

  def payouts
    @payouts = commission_payouts_with_pagination
    @payout_summary = payout_summary_data
  end

  def affiliates
    @affiliates_count = count_user_affiliates
    @affiliates_commission = calculate_affiliates_commission
    @top_performers = top_affiliate_performers
  end

  private

  def ensure_distributor_access
    unless current_user&.user_type == 'distributor' || current_user&.role == 'distributor'
      redirect_to root_path, alert: 'Access denied. Distributor privileges required.'
    end
  end

  def calculate_total_commission
    case current_user.user_type
    when 'distributor'
      DistributorPayout.where(distributor_id: current_user.id).sum(:payout_amount) || 0
    else
      0
    end
  end

  def calculate_monthly_commission
    case current_user.user_type
    when 'distributor'
      DistributorPayout.where(distributor_id: current_user.id)
                      .where(created_at: Date.current.beginning_of_month..Date.current.end_of_month)
                      .sum(:payout_amount) || 0
    else
      0
    end
  end

  def calculate_pending_commission
    case current_user.user_type
    when 'distributor'
      DistributorPayout.where(distributor_id: current_user.id)
                      .where(status: ['pending', 'processing'])
                      .sum(:payout_amount) || 0
    else
      0
    end
  end

  def count_total_policies
    case current_user.user_type
    when 'distributor'
      DistributorPayout.where(distributor_id: current_user.id).count
    else
      0
    end
  end

  def recent_commission_payouts
    case current_user.user_type
    when 'distributor'
      DistributorPayout.where(distributor_id: current_user.id).order(created_at: :desc)
    else
      DistributorPayout.none
    end
  end

  def monthly_commission_chart_data
    unless current_user.user_type == 'distributor'
      return 12.times.map { |i|
        { month: (Date.current - i.months).beginning_of_month.strftime('%b %Y'), amount: 0 }
      }.reverse
    end

    start_date = 11.months.ago.beginning_of_month
    sums = DistributorPayout
      .where(distributor_id: current_user.id, created_at: start_date.beginning_of_day..Time.current)
      .group("DATE_TRUNC('month', created_at)")
      .sum(:payout_amount)
      .transform_keys { |k| k.to_date.strftime('%Y-%m') }

    12.times.map do |i|
      month = (Date.current - i.months).beginning_of_month
      { month: month.strftime('%b %Y'), amount: sums[month.strftime('%Y-%m')] || 0 }
    end.reverse
  end

  def commission_reports_data
    base_query = case current_user.user_type
                 when 'distributor'
                   DistributorPayout.where(distributor_id: current_user.id)
                 else
                   DistributorPayout.none
                 end

    # Apply date range filter
    case @date_range
    when 'this_week'
      base_query = base_query.where(created_at: Date.current.beginning_of_week..Date.current.end_of_week)
    when 'this_month'
      base_query = base_query.where(created_at: Date.current.beginning_of_month..Date.current.end_of_month)
    when 'last_month'
      base_query = base_query.where(created_at: 1.month.ago.beginning_of_month..1.month.ago.end_of_month)
    when 'this_year'
      base_query = base_query.where(created_at: Date.current.beginning_of_year..Date.current.end_of_year)
    end

    # Apply policy type filter
    unless @policy_type == 'all'
      base_query = base_query.where(policy_type: @policy_type)
    end

    base_query.order(created_at: :desc).limit(50)
  end

  def commission_breakdown_data
    case current_user.user_type
    when 'distributor'
      {
        health_insurance: DistributorPayout.where(distributor_id: current_user.id, policy_type: 'HealthInsurance').sum(:payout_amount),
        life_insurance: DistributorPayout.where(distributor_id: current_user.id, policy_type: 'LifeInsurance').sum(:payout_amount),
        motor_insurance: DistributorPayout.where(distributor_id: current_user.id, policy_type: 'MotorInsurance').sum(:payout_amount)
      }
    else
      { health_insurance: 0, life_insurance: 0, motor_insurance: 0 }
    end
  end

  def commission_payouts_with_pagination
    per_page = params[:per_page]&.to_i || 20
    page = params[:page]&.to_i || 1
    offset = (page - 1) * per_page

    case current_user.user_type
    when 'distributor'
      DistributorPayout.where(distributor_id: current_user.id)
                      .order(created_at: :desc)
                      .limit(per_page)
                      .offset(offset)
    else
      DistributorPayout.none
    end
  end

  def payout_summary_data
    case current_user.user_type
    when 'distributor'
      base_query = DistributorPayout.where(distributor_id: current_user.id)

      {
        total_payouts: base_query.sum(:payout_amount),
        completed_payouts: base_query.where(status: 'completed').sum(:payout_amount),
        pending_payouts: base_query.where(status: ['pending', 'processing']).sum(:payout_amount),
        total_count: base_query.count
      }
    else
      { total_payouts: 0, completed_payouts: 0, pending_payouts: 0, total_count: 0 }
    end
  end

  def count_user_affiliates
    # This would depend on your affiliate/referral system structure
    # For now, returning 0 as placeholder
    0
  end

  def calculate_affiliates_commission
    # This would calculate commission from referred affiliates
    # For now, returning 0 as placeholder
    0
  end

  def top_affiliate_performers
    # This would return top performing affiliates
    # For now, returning empty array as placeholder
    []
  end

end