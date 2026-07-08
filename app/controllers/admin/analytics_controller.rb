require 'ostruct'

class Admin::AnalyticsController < Admin::ApplicationController
  def index
    setup_filter_dates
    # Always use filtered queries so dashboard and analytics show matching data
    # for the same date range. setup_filter_dates defaults to the current year
    # when no params are present, which mirrors the dashboard's default behaviour.
    load_filtered_analytics_data

    # AJAX chart-data requests return JSON from the already-loaded instance vars
    if request.xhr? && params[:chart].present?
      render json: get_chart_data(params[:chart])
      return
    end
  end

  def refresh
    refresh_analytics_cache
    redirect_to admin_analytics_path, notice: 'Analytics data has been refreshed!'
  end

  def card_detail
    setup_filter_dates
    metric  = params[:metric].to_s
    records = fetch_analytics_card_records(metric)
    render json: { records: records, metric: metric, count: records.size }
  rescue => e
    render json: { error: e.message }, status: 422
  end

  private

  # DR-wise filter: admin-added policies only (source of truth matches list pages).
  DRWISE = { is_admin_added: true, is_customer_added: false, is_agent_added: false }.freeze

  def setup_filter_dates
    current_year = Date.current.year

    if params[:financial_year].present?
      fy = params[:financial_year].to_i.clamp(2000, 2100)
      @filter_financial_year = fy
      @filter_year  = fy
      @filter_month = nil
      @filter_start_date = Date.new(fy - 1, 4, 1)
      @filter_end_date   = Date.new(fy,     3, 31)
    else
      @filter_financial_year = nil
      @filter_year  = params[:year].present? ? params[:year].to_i.clamp(2000, 2100) : current_year
      @filter_month = params[:month].present? ? params[:month].to_i.clamp(1, 12) : nil
      @filter_start_date = if params[:start_date].present?
        date = Date.parse(params[:start_date]) rescue nil
        (date && date.year >= 2000 && date.year <= 2100) ? date : Date.new(@filter_year, 1, 1)
      else
        Date.new(@filter_year, 1, 1)
      end
      @filter_end_date = if params[:end_date].present?
        date = Date.parse(params[:end_date]) rescue nil
        (date && date.year >= 2000 && date.year <= 2100) ? date : Date.new(@filter_year, 12, 31)
      else
        Date.new(@filter_year, 12, 31)
      end

      if @filter_month.present?
        @filter_start_date = Date.new(@filter_year, @filter_month, 1)
        @filter_end_date   = @filter_start_date.end_of_month
      end
    end
  end

  def has_filter_params?
    params[:year].present? || params[:month].present? || params[:start_date].present? || params[:end_date].present?
  end

  def load_filtered_analytics_data
    Rails.logger.info "🔍 Loading filtered analytics data for period: #{@filter_start_date} to #{@filter_end_date}"

    # Use the same filtered data approach as dashboard controller
    filtered_data = get_filtered_analytics_data(@filter_start_date, @filter_end_date)

    # Set instance variables from filtered data
    filtered_data.each { |key, value| instance_variable_set("@#{key}", value) }
  end

  def get_filtered_analytics_data(start_date, end_date)
    # Time ranges
    @current_month = start_date.beginning_of_month
    @last_month = (start_date - 1.month).beginning_of_month
    @current_year = start_date.beginning_of_year
    @last_year = (start_date - 1.year).beginning_of_year

    # Core metrics for the filtered period
    # Policies/premium use policy_start_date; people/leads use created_at
    dt_start = start_date.beginning_of_day
    dt_end   = end_date.end_of_day
    @total_customers   = Customer.where(created_at: dt_start..dt_end).count
    @total_policies    = calculate_total_policies_for_period(start_date, end_date)
    @total_premium     = calculate_total_premium_for_period(start_date, end_date)
    @total_affiliates  = SubAgent.where(created_at: dt_start..dt_end).count
    @total_ambassadors = Distributor.where(created_at: dt_start..dt_end).count

    # Growth metrics (compare with previous period of same duration)
    # Use .to_i to get integer days; avoid double .days conversion which overflows PostgreSQL
    days_in_period = (end_date - start_date).to_i
    previous_end   = start_date - 1.day
    previous_start = [start_date - days_in_period, Date.new(1900, 1, 1)].max

    @customer_growth = calculate_growth_for_period(Customer, start_date, end_date, previous_start, previous_end)
    @policy_growth = calculate_policy_growth_for_period(start_date, end_date, previous_start, previous_end)
    @premium_growth = calculate_premium_growth_for_period(start_date, end_date, previous_start, previous_end)
    @affiliate_growth = calculate_growth_for_period(SubAgent, start_date, end_date, previous_start, previous_end)

    # Policy distribution for the filtered period (filter by policy_start_date)
    @policy_distribution = {
      'Life Insurance'   => LifeInsurance.where(DRWISE).where(policy_start_date: start_date..end_date).count,
      'Health Insurance' => HealthInsurance.where(DRWISE).where(policy_start_date: start_date..end_date).count,
      'Motor Insurance'  => (MotorInsurance.where(DRWISE).where(policy_start_date: start_date..end_date).count rescue 0),
      'Other Insurance'  => (OtherInsurance.where(DRWISE).where(policy_start_date: start_date..end_date).count rescue 0)
    }

    # Monthly trends within the filtered period (up to 12 months)
    @monthly_trends = calculate_monthly_trends_for_period(start_date, end_date)

    # Top performing affiliates for the period
    @top_affiliates = calculate_top_affiliates_for_period(start_date, end_date)

    # Recent activities for the period
    @recent_policies = get_recent_policies_for_period(start_date, end_date)
    @recent_leads = Lead.where(created_at: dt_start..dt_end).order(created_at: :desc).limit(10)

    # Commission analytics for the period
    @commission_summary = calculate_commission_summary_for_period(start_date, end_date)

    # Renewal analytics for the period
    @renewal_analytics = calculate_renewal_analytics_for_period(start_date, end_date)

    # Lead analytics for the period
    @lead_conversion_funnel = calculate_lead_conversion_funnel_for_period(start_date, end_date)
    @lead_stage_distribution = calculate_lead_stage_distribution_for_period(start_date, end_date)

    # Customer location analytics for the period
    @customer_location = calculate_customer_location_for_period(start_date, end_date)

    # Additional metrics
    @conversion_rate = calculate_conversion_rate_for_period(start_date, end_date, dt_start, dt_end)
    @avg_policy_value = @total_policies > 0 ? (@total_premium / @total_policies).round(0) : 0
    @commissions_due = (@commission_summary[:total_commission_due] || 0).to_f

    # Top customers by premium for the filtered period
    @top_customers_by_premium = calculate_top_customers_by_premium_for_period(start_date, end_date)

    # Investor analytics (all-time — investors don't have a policy_start_date)
    @total_investors = Investor.count rescue 0
    @investor_status_distribution = calculate_investor_status_distribution
    @top_investors_by_ambassadors = calculate_top_investors_by_ambassadors
    @top_investors_by_commission = calculate_top_investors_by_commission

    # Premium revenue trend for the filtered period (month-by-month within the range)
    @premium_revenue_trend = {}
    cur = start_date.beginning_of_month
    while cur <= end_date
      m_start = [cur, start_date].max
      m_end   = [cur.end_of_month, end_date].min
      range   = m_start..m_end
      h = HealthInsurance.where(DRWISE).where(policy_start_date: range).sum(:net_premium)
      l = LifeInsurance.where(DRWISE).where(policy_start_date: range).sum(:net_premium)
      m = (MotorInsurance.where(DRWISE).where(policy_start_date: range).sum(:net_premium) rescue 0)
      @premium_revenue_trend[cur.strftime('%b %Y')] = (h + l + m).round(0)
      cur = cur.next_month
    end

    # Customer acquisition trend for the filtered period
    @customer_acquisition_trend = {}
    cur = start_date.beginning_of_month
    while cur <= end_date
      m_start = [cur, start_date].max.beginning_of_day
      m_end   = [cur.end_of_month, end_date].min.end_of_day
      @customer_acquisition_trend[cur.strftime('%b %Y')] = Customer.where(created_at: m_start..m_end).count
      cur = cur.next_month
    end

    # Agent performance — all-time; filtering by period is a separate enhancement
    @agent_performance    = calculate_agent_performance
    @agent_commission     = calculate_agent_commission
    @agent_customer_data  = calculate_agent_customer_data
    @customer_retention   = calculate_customer_retention

    # Operational quick-insights for the filtered period
    @active_customers = Customer.where(created_at: dt_start..dt_end).where(status: true).count rescue Customer.where(created_at: dt_start..dt_end).count
    @converted_leads  = Lead.where(created_at: dt_start..dt_end, current_stage: %w[policy_created converted]).count rescue 0
    @new_leads        = Lead.where(created_at: dt_start..dt_end).count rescue 0
    @support_tickets  = calculate_support_tickets
    @docs_pending     = 0
    @claims_processing = 0
    @client_requests_count = 0
    @data_is_cached   = false

    # Return only the filter metadata; instance variables are already set above
    {
      filter_start_date: start_date,
      filter_end_date: end_date,
      filter_year: start_date.year,
      filter_month: start_date.month == end_date.month ? start_date.month : nil
    }
  end

  # Helper methods for filtered calculations
  def calculate_total_policies_for_period(start_date, end_date)
    range = start_date..end_date
    HealthInsurance.where(DRWISE).where(policy_start_date: range).count +
    LifeInsurance.where(DRWISE).where(policy_start_date: range).count +
    (MotorInsurance.where(DRWISE).where(policy_start_date: range).count rescue 0) +
    (OtherInsurance.where(DRWISE).where(policy_start_date: range).count rescue 0)
  end

  def calculate_total_premium_for_period(start_date, end_date)
    range = start_date..end_date
    (HealthInsurance.where(DRWISE).where(policy_start_date: range).sum(:net_premium) || 0) +
    (LifeInsurance.where(DRWISE).where(policy_start_date: range).sum(:net_premium) || 0) +
    (MotorInsurance.where(DRWISE).where(policy_start_date: range).sum(:net_premium) || 0 rescue 0) +
    (OtherInsurance.where(DRWISE).where(policy_start_date: range).sum(:net_premium) || 0 rescue 0)
  end

  def calculate_growth_for_period(model, current_start, current_end, previous_start, previous_end)
    current_count = model.where(created_at: current_start..current_end).count
    previous_count = model.where(created_at: previous_start..previous_end).count

    return 0 if previous_count == 0
    ((current_count.to_f - previous_count.to_f) / previous_count.to_f * 100).round(1)
  end

  def calculate_policy_growth_for_period(current_start, current_end, previous_start, previous_end)
    current_policies = calculate_total_policies_for_period(current_start, current_end)
    previous_policies = calculate_total_policies_for_period(previous_start, previous_end)

    return 0 if previous_policies == 0
    ((current_policies.to_f - previous_policies.to_f) / previous_policies.to_f * 100).round(1)
  end

  def calculate_premium_growth_for_period(current_start, current_end, previous_start, previous_end)
    current_premium = calculate_total_premium_for_period(current_start, current_end)
    previous_premium = calculate_total_premium_for_period(previous_start, previous_end)

    return 0 if previous_premium == 0
    ((current_premium.to_f - previous_premium.to_f) / previous_premium.to_f * 100).round(1)
  end

  def calculate_monthly_trends_for_period(start_date, end_date)
    trends = {}
    current_date = start_date.beginning_of_month

    while current_date <= end_date
      month_end = [current_date.end_of_month, end_date].min
      month_name = current_date.strftime('%b %Y')

      # Customers and leads filter by created_at; policies/premium by policy_start_date
      trends[month_name] = {
        customers: Customer.where(created_at: current_date.beginning_of_day..month_end.end_of_day).count,
        policies:  calculate_policies_for_month_in_period(current_date, month_end),
        premium:   calculate_premium_for_month_in_period(current_date, month_end),
        leads:     Lead.where(created_at: current_date.beginning_of_day..month_end.end_of_day).count
      }

      current_date = current_date.next_month.beginning_of_month
    end

    trends
  end

  def calculate_policies_for_month_in_period(month_start, month_end)
    range = month_start..month_end
    HealthInsurance.where(DRWISE).where(policy_start_date: range).count +
    LifeInsurance.where(DRWISE).where(policy_start_date: range).count +
    (MotorInsurance.where(DRWISE).where(policy_start_date: range).count rescue 0) +
    (OtherInsurance.where(DRWISE).where(policy_start_date: range).count rescue 0)
  end

  def calculate_premium_for_month_in_period(month_start, month_end)
    range = month_start..month_end
    HealthInsurance.where(DRWISE).where(policy_start_date: range).sum(:net_premium) +
    LifeInsurance.where(DRWISE).where(policy_start_date: range).sum(:net_premium) +
    (MotorInsurance.where(DRWISE).where(policy_start_date: range).sum(:net_premium) || 0 rescue 0) +
    (OtherInsurance.where(DRWISE).where(policy_start_date: range).sum(:net_premium) || 0 rescue 0)
  end

  def calculate_top_affiliates_for_period(start_date, end_date)
    affiliate_data = SubAgent.joins(
      "LEFT JOIN health_insurances hi ON hi.sub_agent_id = sub_agents.id AND hi.is_admin_added = true AND hi.is_customer_added = false AND hi.is_agent_added = false AND hi.policy_start_date BETWEEN '#{start_date}' AND '#{end_date}'" +
      " LEFT JOIN life_insurances li ON li.sub_agent_id = sub_agents.id AND li.is_admin_added = true AND li.is_customer_added = false AND li.is_agent_added = false AND li.policy_start_date BETWEEN '#{start_date}' AND '#{end_date}'" +
      " LEFT JOIN motor_insurances mi ON mi.sub_agent_id = sub_agents.id AND mi.is_admin_added = true AND mi.is_customer_added = false AND mi.is_agent_added = false AND mi.policy_start_date BETWEEN '#{start_date}' AND '#{end_date}'"
    )
    .select("sub_agents.id, sub_agents.first_name, sub_agents.last_name, sub_agents.status,
             (COALESCE(COUNT(DISTINCT hi.id), 0) + COALESCE(COUNT(DISTINCT li.id), 0) + COALESCE(COUNT(DISTINCT mi.id), 0)) as policies_count")
    .group("sub_agents.id, sub_agents.first_name, sub_agents.last_name, sub_agents.status")
    .having("(COALESCE(COUNT(DISTINCT hi.id), 0) + COALESCE(COUNT(DISTINCT li.id), 0) + COALESCE(COUNT(DISTINCT mi.id), 0)) > 0")
    .order("policies_count DESC")
    .limit(10)

    affiliate_data.map { |agent| OpenStruct.new(
      id: agent.id,
      first_name: agent.first_name,
      last_name: agent.last_name,
      status: agent.status || 'active',
      policies_count: agent.policies_count
    )}
  rescue => e
    Rails.logger.error "Error calculating top affiliates for period: #{e.message}"
    []
  end

  def get_recent_policies_for_period(start_date, end_date)
    policies = []

    HealthInsurance.where(DRWISE).includes(:customer).where(policy_start_date: start_date..end_date).order(policy_start_date: :desc).limit(3).each do |policy|
      policies << {
        type: 'Health Insurance',
        customer: policy.customer&.display_name&.presence || 'Unknown',
        policy_number: policy.policy_number,
        premium: policy.net_premium.to_f,
        date: policy.policy_start_date
      }
    end

    LifeInsurance.where(DRWISE).includes(:customer).where(policy_start_date: start_date..end_date).order(policy_start_date: :desc).limit(3).each do |policy|
      policies << {
        type: 'Life Insurance',
        customer: policy.customer&.display_name&.presence || 'Unknown',
        policy_number: policy.policy_number,
        premium: policy.net_premium.to_f,
        date: policy.policy_start_date
      }
    end

    begin
      MotorInsurance.where(DRWISE).includes(:customer).where(policy_start_date: start_date..end_date).order(policy_start_date: :desc).limit(2).each do |policy|
        policies << {
          type: 'Motor Insurance',
          customer: policy.customer&.display_name&.presence || 'Unknown',
          policy_number: policy.policy_number,
          premium: policy.net_premium.to_f,
          date: policy.policy_start_date
        }
      end
    rescue; end

    policies.sort_by { |p| p[:date] || Date.new(1900) }.reverse.first(10)
  end

  def calculate_top_customers_by_premium_for_period(start_date, end_date)
    range = start_date..end_date
    totals = Hash.new(0.0)

    [HealthInsurance, LifeInsurance].each do |model|
      model.where(DRWISE).where(policy_start_date: range)
           .joins(:customer)
           .group("CONCAT(customers.first_name, ' ', customers.last_name)")
           .sum(:net_premium)
           .each { |name, amt| totals[name.strip] += amt.to_f }
    end

    begin
      MotorInsurance.where(DRWISE).where(policy_start_date: range)
                    .joins(:customer)
                    .group("CONCAT(customers.first_name, ' ', customers.last_name)")
                    .sum(:net_premium)
                    .each { |name, amt| totals[name.strip] += amt.to_f }
    rescue; end

    totals.sort_by { |_, v| -v }.first(8).to_h
  rescue => e
    Rails.logger.error "Error calculating top customers: #{e.message}"
    {}
  end

  def calculate_commission_summary_for_period(start_date, end_date)
    dt_start = start_date.beginning_of_day
    dt_end   = end_date.end_of_day
    {
      total_commission_due:    CommissionPayout.where(status: 'pending', created_at: dt_start..dt_end).sum(:payout_amount),
      total_commission_paid:   CommissionPayout.where(status: 'paid',    created_at: dt_start..dt_end).sum(:payout_amount),
      affiliate_commissions:   CommissionPayout.where(payout_to: 'sub_agent',  status: 'pending', created_at: dt_start..dt_end).sum(:payout_amount),
      ambassador_commissions:  CommissionPayout.where(payout_to: 'ambassador', status: 'pending', created_at: dt_start..dt_end).sum(:payout_amount)
    }
  end

  def calculate_renewal_analytics_for_period(start_date, end_date)
    end_plus_30 = end_date + 30.days
    end_plus_60 = end_date + 60.days

    {
      expiring_soon: calculate_expiring_policies_for_period(start_date, end_date, end_date, end_plus_30),
      expiring_later: calculate_expiring_policies_for_period(start_date, end_date, end_plus_30, end_plus_60),
      expired: calculate_expired_policies_for_period(start_date, end_date),
      renewal_rate: calculate_renewal_rate_for_period(start_date, end_date)
    }
  end

  def calculate_expiring_policies_for_period(policy_start, policy_end, expiry_start, expiry_end)
    HealthInsurance.where(DRWISE).where(policy_start_date: policy_start..policy_end, policy_end_date: expiry_start..expiry_end).count +
    LifeInsurance.where(DRWISE).where(policy_start_date: policy_start..policy_end, policy_end_date: expiry_start..expiry_end).count +
    (MotorInsurance.where(DRWISE).where(policy_start_date: policy_start..policy_end, policy_end_date: expiry_start..expiry_end).count rescue 0) +
    (OtherInsurance.where(DRWISE).where(policy_start_date: policy_start..policy_end, policy_end_date: expiry_start..expiry_end).count rescue 0)
  end

  def calculate_expired_policies_for_period(start_date, end_date)
    HealthInsurance.where(DRWISE).where(policy_start_date: start_date..end_date).where('policy_end_date < ?', Date.current).count +
    LifeInsurance.where(DRWISE).where(policy_start_date: start_date..end_date).where('policy_end_date < ?', Date.current).count +
    (MotorInsurance.where(DRWISE).where(policy_start_date: start_date..end_date).where('policy_end_date < ?', Date.current).count rescue 0) +
    (OtherInsurance.where(DRWISE).where(policy_start_date: start_date..end_date).where('policy_end_date < ?', Date.current).count rescue 0)
  end

  def calculate_renewal_rate_for_period(start_date, end_date)
    total_eligible = LifeInsurance.where(DRWISE).where(policy_start_date: start_date..end_date).where('policy_end_date < ?', Date.current).count +
                     HealthInsurance.where(DRWISE).where(policy_start_date: start_date..end_date).where('policy_end_date < ?', Date.current).count
    renewed = LifeInsurance.where(DRWISE).where(policy_start_date: start_date..end_date, policy_type: 'Renewal').count +
              HealthInsurance.where(DRWISE).where(policy_start_date: start_date..end_date, policy_type: 'Renewal').count

    return 0 if total_eligible == 0
    ((renewed.to_f / total_eligible.to_f) * 100).round(1)
  end

  def calculate_lead_conversion_funnel_for_period(start_date, end_date)
    dt_start = start_date.beginning_of_day
    dt_end   = end_date.end_of_day
    {
      'Lead Generated'           => Lead.where(created_at: dt_start..dt_end, current_stage: 'lead_generated').count,
      'Consultation Scheduled'   => Lead.where(created_at: dt_start..dt_end, current_stage: 'consultation_scheduled').count,
      'One on One'               => Lead.where(created_at: dt_start..dt_end, current_stage: 'one_on_one').count,
      'Follow Up'                => Lead.where(created_at: dt_start..dt_end, current_stage: %w[follow_up re_follow_up]).count,
      'Converted'                => Lead.where(created_at: dt_start..dt_end, current_stage: 'converted').count
    }
  rescue => e
    Rails.logger.error "Error calculating lead conversion funnel for period: #{e.message}"
    { 'Lead Generated' => 0, 'Consultation Scheduled' => 0, 'One on One' => 0, 'Follow Up' => 0, 'Converted' => 0 }
  end

  def calculate_lead_stage_distribution_for_period(start_date, end_date)
    dt_start = start_date.beginning_of_day
    dt_end   = end_date.end_of_day
    {
      'Lead Generated'         => Lead.where(created_at: dt_start..dt_end, current_stage: 'lead_generated').count,
      'Consultation Scheduled' => Lead.where(created_at: dt_start..dt_end, current_stage: 'consultation_scheduled').count,
      'One on One'             => Lead.where(created_at: dt_start..dt_end, current_stage: 'one_on_one').count,
      'Follow Up'              => Lead.where(created_at: dt_start..dt_end, current_stage: %w[follow_up re_follow_up]).count,
      'Follow Up Successful'   => Lead.where(created_at: dt_start..dt_end, current_stage: 'follow_up_successful').count,
      'Follow Up Unsuccessful' => Lead.where(created_at: dt_start..dt_end, current_stage: 'follow_up_unsuccessful').count,
      'Not Interested'         => Lead.where(created_at: dt_start..dt_end, current_stage: 'not_interested').count,
      'Converted'              => Lead.where(created_at: dt_start..dt_end, current_stage: 'converted').count,
      'Lead Closed'            => Lead.where(created_at: dt_start..dt_end, current_stage: 'lead_closed').count
    }
  rescue => e
    Rails.logger.error "Error calculating lead stage distribution for period: #{e.message}"
    { 'Lead Generated' => 0, 'Consultation Scheduled' => 0, 'One on One' => 0, 'Follow Up' => 0,
      'Follow Up Successful' => 0, 'Follow Up Unsuccessful' => 0, 'Not Interested' => 0,
      'Converted' => 0, 'Lead Closed' => 0 }
  end

  def calculate_customer_location_for_period(start_date, end_date)
    dt_start = start_date.beginning_of_day
    dt_end   = end_date.end_of_day
    location_data = {}

    Customer.where(created_at: dt_start..dt_end).group(:city).count.each do |city, count|
      next if city.blank?
      location_data[city.to_s.titleize] = count
    end

    if location_data.empty?
      Customer.where(created_at: dt_start..dt_end).group(:state).count.each do |state, count|
        next if state.blank?
        location_data[state.to_s.titleize] = count
      end
    end

    location_data = { 'Unknown' => Customer.where(created_at: dt_start..dt_end).count } if location_data.empty?
    location_data
  rescue => e
    Rails.logger.error "Error calculating customer location for period: #{e.message}"
    { 'Unknown' => 0 }
  end

  def calculate_conversion_rate_for_period(start_date, end_date, dt_start = nil, dt_end = nil)
    dt_start ||= start_date.beginning_of_day
    dt_end   ||= end_date.end_of_day
    total_leads = Lead.where(created_at: dt_start..dt_end).count
    converted   = Lead.where(created_at: dt_start..dt_end, current_stage: 'converted').count

    return 0 if total_leads == 0
    ((converted.to_f / total_leads.to_f) * 100).round(1)
  rescue => e
    Rails.logger.error "Error calculating conversion rate for period: #{e.message}"
    0
  end

  def get_chart_data(chart_name)
    case chart_name
    when 'policyDistribution'
      {
        labels: @policy_distribution.keys,
        data: @policy_distribution.values
      }
    when 'monthlyTrends'
      {
        labels: @monthly_trends.keys,
        datasets: [
          {
            label: 'Customers',
            data: @monthly_trends.values.map { |v| v[:customers] }
          },
          {
            label: 'Policies',
            data: @monthly_trends.values.map { |v| v[:policies] }
          }
        ]
      }
    when 'leadConversion'
      {
        labels: @lead_conversion_funnel.keys,
        data: @lead_conversion_funnel.values
      }
    when 'leadStage'
      {
        labels: @lead_stage_distribution.keys,
        data: @lead_stage_distribution.values
      }
    else
      { error: 'Chart not found' }
    end
  end

  def refresh_analytics_cache
    Rails.logger.info "🔄 Refreshing analytics cache..."
    AnalyticsCache.clear_cache('main_analytics')
    AnalyticsCache.clear_cache('main_analytics_v3')
    load_fresh_analytics_data
  end

  def load_analytics_data
    cache_identifier = 'main_analytics_v3'

    # Try to get cached data first
    if AnalyticsCache.cache_fresh?(cache_identifier, 1.hour)
      Rails.logger.info "📊 Loading analytics from cache..."
      cached_data = AnalyticsCache.get_cached_data(cache_identifier)
      load_data_from_cache(cached_data) if cached_data
    else
      Rails.logger.info "🔄 Cache miss or stale, loading fresh analytics data..."
      load_fresh_analytics_data
    end

    # Set cache info for UI
    set_cache_info(cache_identifier)
  end

  def load_fresh_analytics_data
    cache_identifier = 'main_analytics_v3'
    start_time = Time.current

    Rails.logger.info "🔄 Starting fresh analytics calculation..."

    # Time ranges
    @current_month = Date.current.beginning_of_month
    @last_month = 1.month.ago.beginning_of_month
    @current_year = Date.current.beginning_of_year
    @last_year = 1.year.ago.beginning_of_year

    # Core metrics
    @total_customers = Customer.count
    @total_policies = calculate_total_policies
    @total_premium = calculate_total_premium_collected
    @total_affiliates = SubAgent.count
    @total_ambassadors = Distributor.count

    # Growth metrics
    @customer_growth = calculate_growth_percentage(Customer, @current_month)
    @policy_growth = calculate_growth_percentage(HealthInsurance, @current_month) +
                     calculate_growth_percentage(LifeInsurance, @current_month) +
                     calculate_growth_percentage(MotorInsurance, @current_month)
    @premium_growth = calculate_premium_growth
    @affiliate_growth = calculate_growth_percentage(SubAgent, @current_month)

    # Policy distribution
    @policy_distribution = {
      'Life Insurance'   => LifeInsurance.where(DRWISE).count,
      'Health Insurance' => HealthInsurance.where(DRWISE).count,
      'Motor Insurance'  => (MotorInsurance.where(DRWISE).count rescue 0),
      'Other Insurance'  => (OtherInsurance.where(DRWISE).count rescue 0)
    }

    # Monthly trends (last 12 months)
    @monthly_trends = calculate_monthly_trends

    # Top performing affiliates
    @top_affiliates = calculate_top_affiliates

    # Recent activities
    @recent_policies = get_recent_policies
    @recent_leads = Lead.order(created_at: :desc).limit(10)

    # Commission analytics
    @commission_summary = calculate_commission_summary

    # Renewal analytics
    @renewal_analytics = calculate_renewal_analytics

    # Agent performance analytics
    @agent_performance = calculate_agent_performance

    # Agent customer data for affiliate performance table
    @agent_customer_data = calculate_agent_customer_data

    # Actual commission per agent from CommissionPayout records
    @agent_commission = calculate_agent_commission

    # Commission metrics
    @commissions_due = (@commission_summary[:total_commission_due] || 0).to_f
    @conversion_rate = calculate_conversion_rate.to_f

    # Additional metrics for KPI cards
    @avg_policy_value = calculate_avg_policy_value
    @customer_retention = calculate_customer_retention

    # Lead conversion funnel
    @lead_conversion_funnel = calculate_lead_conversion_funnel

    # Lead stage distribution for analytics view
    @lead_stage_distribution = calculate_lead_stage_distribution

    # Customer location analytics
    @customer_location = calculate_customer_location

    # Customer acquisition trend (last 12 months)
    @customer_acquisition_trend = calculate_customer_acquisition_trend

    # Premium Revenue Trend (last 12 months)
    @premium_revenue_trend = calculate_premium_revenue_trend

    # Quick Insights data
    @active_customers = calculate_active_customers
    @converted_leads = calculate_converted_leads
    @new_leads = calculate_new_leads
    @support_tickets = calculate_support_tickets

    # Operations Overview data
    @docs_pending = calculate_docs_pending
    @claims_processing = calculate_claims_processing
    @client_requests_count = calculate_client_requests_count

    # Investor analytics
    @total_investors = Investor.count rescue 0
    @investor_status_distribution = calculate_investor_status_distribution
    @top_investors_by_ambassadors = calculate_top_investors_by_ambassadors
    @top_investors_by_commission = calculate_top_investors_by_commission

    # Cache the calculated data
    analytics_data = {
      current_month: @current_month,
      last_month: @last_month,
      current_year: @current_year,
      last_year: @last_year,
      total_customers: @total_customers,
      total_policies: @total_policies,
      total_premium: @total_premium,
      total_affiliates: @total_affiliates,
      total_ambassadors: @total_ambassadors,
      customer_growth: @customer_growth,
      policy_growth: @policy_growth,
      premium_growth: @premium_growth,
      affiliate_growth: @affiliate_growth,
      policy_distribution: @policy_distribution,
      monthly_trends: @monthly_trends,
      top_affiliates: @top_affiliates.map(&:to_h),
      recent_policies: @recent_policies,
      recent_leads: @recent_leads.map(&:attributes),
      commission_summary: @commission_summary,
      renewal_analytics: @renewal_analytics,
      agent_performance: @agent_performance.transform_values(&:to_f),
      agent_customer_data: @agent_customer_data,
      agent_commission: @agent_commission.transform_values(&:to_f),
      commissions_due: @commissions_due,
      conversion_rate: @conversion_rate,
      avg_policy_value: @avg_policy_value,
      customer_retention: @customer_retention,
      lead_conversion_funnel: @lead_conversion_funnel,
      lead_stage_distribution: @lead_stage_distribution,
      customer_location: @customer_location,
      customer_acquisition_trend: @customer_acquisition_trend,
      premium_revenue_trend: @premium_revenue_trend,
      active_customers: @active_customers,
      converted_leads: @converted_leads,
      new_leads: @new_leads,
      support_tickets: @support_tickets,
      docs_pending: @docs_pending,
      claims_processing: @claims_processing,
      client_requests_count: @client_requests_count,
      total_investors: @total_investors,
      investor_status_distribution: @investor_status_distribution,
      top_investors_by_ambassadors: @top_investors_by_ambassadors,
      top_investors_by_commission: @top_investors_by_commission
    }

    AnalyticsCache.cache_analytics_data(cache_identifier, analytics_data)

    calculation_time = (Time.current - start_time).round(2)
    Rails.logger.info "✅ Fresh analytics calculated and cached in #{calculation_time}s"
  end

  def load_data_from_cache(cached_data)
    @current_month = cached_data['current_month']&.to_date
    @last_month = cached_data['last_month']&.to_date
    @current_year = cached_data['current_year']&.to_date
    @last_year = cached_data['last_year']&.to_date
    @total_customers = cached_data['total_customers'].to_i
    @total_policies = cached_data['total_policies'].to_i
    @total_premium = cached_data['total_premium'].to_f
    @total_affiliates = cached_data['total_affiliates'].to_i
    @total_ambassadors = cached_data['total_ambassadors'].to_i
    @customer_growth = cached_data['customer_growth'].to_f
    @policy_growth = cached_data['policy_growth'].to_f
    @premium_growth = cached_data['premium_growth'].to_f
    @affiliate_growth = cached_data['affiliate_growth'].to_f
    @policy_distribution = cached_data['policy_distribution']
    @monthly_trends = cached_data['monthly_trends']

    # Convert Hash objects back to OpenStruct for compatibility with view
    @top_affiliates = (cached_data['top_affiliates'] || []).map do |affiliate_hash|
      OpenStruct.new(affiliate_hash)
    end

    @recent_policies = (cached_data['recent_policies'] || []).map do |p|
      {
        type:    p['type'],
        customer: p['customer'],
        policy_number: p['policy_number'],
        premium:  p['premium'].to_f,
        date:    p['date'].present? ? Time.parse(p['date']) : nil
      }
    end

    # Convert recent leads back to objects for view compatibility
    @recent_leads = (cached_data['recent_leads'] || []).map do |lead_hash|
      OpenStruct.new(lead_hash)
    end
    @commission_summary = cached_data['commission_summary']
    @renewal_analytics = cached_data['renewal_analytics']
    @agent_performance = (cached_data['agent_performance'] || {}).transform_values(&:to_f)
    @agent_customer_data = cached_data['agent_customer_data']
    @agent_commission = (cached_data['agent_commission'] || {}).transform_values(&:to_f)
    @commissions_due = (cached_data['commissions_due'] || 0).to_f
    @conversion_rate = (cached_data['conversion_rate'] || 0).to_f
    @avg_policy_value = cached_data['avg_policy_value']
    @customer_retention = cached_data['customer_retention']
    @lead_conversion_funnel = cached_data['lead_conversion_funnel']
    @lead_stage_distribution = cached_data['lead_stage_distribution']
    @customer_location = cached_data['customer_location']
    @customer_acquisition_trend = cached_data['customer_acquisition_trend']
    @premium_revenue_trend = cached_data['premium_revenue_trend']
    @active_customers = cached_data['active_customers'] || 0
    @converted_leads = cached_data['converted_leads'] || 0
    @new_leads = cached_data['new_leads'] || 0
    @support_tickets = cached_data['support_tickets'] || 0
    @docs_pending = cached_data['docs_pending'] || 0
    @claims_processing = cached_data['claims_processing'] || 0
    @client_requests_count = cached_data['client_requests_count'] || 0
    @total_investors = cached_data['total_investors'] || 0
    @investor_status_distribution = cached_data['investor_status_distribution'] || { 'Active' => 0, 'Inactive' => 0 }
    @top_investors_by_ambassadors = cached_data['top_investors_by_ambassadors'] || {}
    @top_investors_by_commission = cached_data['top_investors_by_commission'] || {}
  end

  def set_cache_info(cache_identifier)
    cache_record = AnalyticsCache.find_by(cache_identifier: cache_identifier)
    if cache_record
      @cache_last_updated = cache_record.last_updated
      @cache_age_minutes = cache_record.cache_age_minutes
      @data_is_cached = true
    else
      @cache_last_updated = nil
      @cache_age_minutes = 0
      @data_is_cached = false
    end
  end

  def calculate_total_policies
    HealthInsurance.where(DRWISE).count +
    LifeInsurance.where(DRWISE).count +
    (MotorInsurance.where(DRWISE).count rescue 0) +
    (OtherInsurance.where(DRWISE).count rescue 0)
  end

  def calculate_total_premium_collected
    (HealthInsurance.where(DRWISE).sum(:net_premium) || 0) +
    (LifeInsurance.where(DRWISE).sum(:net_premium) || 0) +
    (MotorInsurance.where(DRWISE).sum(:net_premium) || 0 rescue 0) +
    (OtherInsurance.where(DRWISE).sum(:net_premium) || 0 rescue 0)
  end

  def calculate_growth_percentage(model, period_start)
    current_count = model.where('created_at >= ?', period_start).count
    previous_count = model.where(created_at: (period_start - 1.month)..(period_start - 1.day)).count

    return 0 if previous_count == 0
    ((current_count.to_f - previous_count.to_f) / previous_count.to_f * 100).round(1)
  end

  def calculate_premium_growth
    current_premium = HealthInsurance.where(DRWISE).where(policy_start_date: @current_month..).sum(:net_premium) +
                      LifeInsurance.where(DRWISE).where(policy_start_date: @current_month..).sum(:net_premium) +
                      (MotorInsurance.where(DRWISE).where(policy_start_date: @current_month..).sum(:net_premium) || 0 rescue 0) +
                      (OtherInsurance.where(DRWISE).where(policy_start_date: @current_month..).sum(:net_premium) || 0 rescue 0)

    previous_premium = HealthInsurance.where(DRWISE).where(policy_start_date: @last_month..(@current_month - 1.day)).sum(:net_premium) +
                       LifeInsurance.where(DRWISE).where(policy_start_date: @last_month..(@current_month - 1.day)).sum(:net_premium) +
                       (MotorInsurance.where(DRWISE).where(policy_start_date: @last_month..(@current_month - 1.day)).sum(:net_premium) || 0 rescue 0) +
                       (OtherInsurance.where(DRWISE).where(policy_start_date: @last_month..(@current_month - 1.day)).sum(:net_premium) || 0 rescue 0)

    return 0 if previous_premium == 0
    ((current_premium.to_f - previous_premium.to_f) / previous_premium.to_f * 100).round(1)
  end

  def calculate_monthly_trends
    start_date = 11.months.ago.beginning_of_month
    range_date = start_date.to_date..Date.current
    range_ts   = start_date.beginning_of_day..Time.current.end_of_day

    to_key = ->(ts) { ts.to_date.strftime('%Y-%m') }
    idx    = ->(h)  { h.transform_keys { |k| to_key.(k) } }

    c_counts  = idx.(Customer.where(created_at: range_ts).group("DATE_TRUNC('month', created_at)").count)
    ld_counts = idx.(Lead.where(created_at: range_ts).group("DATE_TRUNC('month', created_at)").count)

    hc = idx.(HealthInsurance.where(DRWISE).where(policy_start_date: range_date).group("DATE_TRUNC('month', policy_start_date)").count)
    lc = idx.(LifeInsurance.where(DRWISE).where(policy_start_date: range_date).group("DATE_TRUNC('month', policy_start_date)").count)
    mc = idx.((MotorInsurance.where(DRWISE).where(policy_start_date: range_date).group("DATE_TRUNC('month', policy_start_date)").count rescue {}))
    oc = idx.((OtherInsurance.where(DRWISE).where(policy_start_date: range_date).group("DATE_TRUNC('month', policy_start_date)").count rescue {}))

    hp = idx.(HealthInsurance.where(DRWISE).where(policy_start_date: range_date).group("DATE_TRUNC('month', policy_start_date)").sum(:net_premium))
    lp = idx.(LifeInsurance.where(DRWISE).where(policy_start_date: range_date).group("DATE_TRUNC('month', policy_start_date)").sum(:net_premium))
    mp = idx.((MotorInsurance.where(DRWISE).where(policy_start_date: range_date).group("DATE_TRUNC('month', policy_start_date)").sum(:net_premium) rescue {}))
    op = idx.((OtherInsurance.where(DRWISE).where(policy_start_date: range_date).group("DATE_TRUNC('month', policy_start_date)").sum(:net_premium) rescue {}))

    trends = {}
    12.times do |i|
      month_date = (Date.current - i.months).beginning_of_month
      k = month_date.strftime('%Y-%m')
      trends[month_date.strftime('%b %Y')] = {
        customers: c_counts[k]  || 0,
        policies:  (hc[k] || 0) + (lc[k] || 0) + (mc[k] || 0) + (oc[k] || 0),
        premium:   (hp[k] || 0) + (lp[k] || 0) + (mp[k] || 0) + (op[k] || 0),
        leads:     ld_counts[k] || 0
      }
    end
    trends.to_a.reverse.to_h
  end

  def calculate_policies_for_month(month_date)
    range = month_date..(month_date.end_of_month)
    HealthInsurance.where(DRWISE).where(policy_start_date: range).count +
    LifeInsurance.where(DRWISE).where(policy_start_date: range).count +
    (MotorInsurance.where(DRWISE).where(policy_start_date: range).count rescue 0) +
    (OtherInsurance.where(DRWISE).where(policy_start_date: range).count rescue 0)
  end

  def calculate_premium_for_month(month_date)
    range = month_date..(month_date.end_of_month)
    HealthInsurance.where(DRWISE).where(policy_start_date: range).sum(:net_premium) +
    LifeInsurance.where(DRWISE).where(policy_start_date: range).sum(:net_premium) +
    (MotorInsurance.where(DRWISE).where(policy_start_date: range).sum(:net_premium) || 0 rescue 0) +
    (OtherInsurance.where(DRWISE).where(policy_start_date: range).sum(:net_premium) || 0 rescue 0)
  end

  def calculate_top_affiliates
    health_counts = HealthInsurance.group(:sub_agent_id).count
    life_counts   = LifeInsurance.group(:sub_agent_id).count
    motor_counts  = MotorInsurance.group(:sub_agent_id).count

    all_ids = (health_counts.keys + life_counts.keys + motor_counts.keys).uniq.compact
    totals  = all_ids.map do |id|
      [(health_counts[id] || 0) + (life_counts[id] || 0) + (motor_counts[id] || 0), id]
    end.select { |cnt, _| cnt > 0 }.sort_by { |cnt, _| -cnt }.first(10)

    top_ids = totals.map(&:last)
    agents  = SubAgent.where(id: top_ids).index_by(&:id)

    totals.filter_map do |cnt, id|
      agent = agents[id]
      next unless agent
      OpenStruct.new(
        id: agent.id, first_name: agent.first_name, last_name: agent.last_name,
        status: agent.status || 'active', policies_count: cnt
      )
    end
  rescue => e
    Rails.logger.error "Error calculating top affiliates: #{e.message}"
    []
  end

  def get_recent_policies
    policies = []

    HealthInsurance.where(DRWISE).includes(:customer).order(created_at: :desc).limit(3).each do |policy|
      policies << {
        type: 'Health Insurance',
        customer: policy.customer&.display_name&.presence || 'Unknown',
        policy_number: policy.policy_number,
        premium: policy.net_premium.to_f,
        date: policy.created_at
      }
    end

    LifeInsurance.where(DRWISE).includes(:customer).order(created_at: :desc).limit(3).each do |policy|
      policies << {
        type: 'Life Insurance',
        customer: policy.customer&.display_name&.presence || 'Unknown',
        policy_number: policy.policy_number,
        premium: policy.net_premium.to_f,
        date: policy.created_at
      }
    end

    begin
      MotorInsurance.where(DRWISE).includes(:customer).order(created_at: :desc).limit(2).each do |policy|
        policies << {
          type: 'Motor Insurance',
          customer: policy.customer&.display_name&.presence || 'Unknown',
          policy_number: policy.policy_number,
          premium: policy.net_premium.to_f,
          date: policy.created_at
        }
      end
    rescue; end

    policies.sort_by { |p| p[:date] || Time.at(0) }.reverse.first(10)
  end

  def calculate_commission_summary
    {
      total_commission_due: CommissionPayout.where(status: 'pending').sum(:payout_amount),
      total_commission_paid: CommissionPayout.where(status: 'paid').sum(:payout_amount),
      affiliate_commissions: CommissionPayout.where(payout_to: 'sub_agent', status: 'pending').sum(:payout_amount),
      ambassador_commissions: CommissionPayout.where(payout_to: 'ambassador', status: 'pending').sum(:payout_amount)
    }
  end

  def calculate_renewal_analytics
    thirty_days_from_now = 30.days.from_now
    sixty_days_from_now = 60.days.from_now

    {
      expiring_soon: calculate_expiring_policies(Date.current, thirty_days_from_now),
      expiring_later: calculate_expiring_policies(thirty_days_from_now, sixty_days_from_now),
      expired: calculate_expired_policies,
      renewal_rate: calculate_renewal_rate
    }
  end

  def calculate_expiring_policies(start_date, end_date)
    HealthInsurance.where(DRWISE).where(policy_end_date: start_date..end_date).count +
    LifeInsurance.where(DRWISE).where(policy_end_date: start_date..end_date).count +
    (MotorInsurance.where(DRWISE).where(policy_end_date: start_date..end_date).count rescue 0) +
    (OtherInsurance.where(DRWISE).where(policy_end_date: start_date..end_date).count rescue 0)
  end

  def calculate_expired_policies
    HealthInsurance.where(DRWISE).where('policy_end_date < ?', Date.current).count +
    LifeInsurance.where(DRWISE).where('policy_end_date < ?', Date.current).count +
    (MotorInsurance.where(DRWISE).where('policy_end_date < ?', Date.current).count rescue 0) +
    (OtherInsurance.where(DRWISE).where('policy_end_date < ?', Date.current).count rescue 0)
  end

  def calculate_renewal_rate
    total_eligible = LifeInsurance.where(DRWISE).where('policy_end_date < ?', Date.current).count +
                     HealthInsurance.where(DRWISE).where('policy_end_date < ?', Date.current).count
    renewed = LifeInsurance.where(DRWISE).where(policy_type: 'Renewal').count +
              HealthInsurance.where(DRWISE).where(policy_type: 'Renewal').count

    return 0 if total_eligible == 0
    ((renewed.to_f / total_eligible.to_f) * 100).round(1)
  end

  def calculate_agent_performance
    agent_premiums = {}

    [
      HealthInsurance.joins(:sub_agent).group("CONCAT(sub_agents.first_name, ' ', sub_agents.last_name)").sum(:net_premium),
      LifeInsurance.joins(:sub_agent).group("CONCAT(sub_agents.first_name, ' ', sub_agents.last_name)").sum(:net_premium),
      MotorInsurance.joins(:sub_agent).group("CONCAT(sub_agents.first_name, ' ', sub_agents.last_name)").sum(:net_premium)
    ].each do |result|
      result.each { |name, premium| agent_premiums[name] = (agent_premiums[name] || 0) + premium.to_f }
    end

    agent_premiums.sort_by { |_, premium| -premium }.to_h
  rescue => e
    Rails.logger.error "Error calculating agent performance: #{e.message}"
    {}
  end

  def calculate_agent_commission
    agent_commissions = {}

    [HealthInsurance, LifeInsurance, MotorInsurance].each do |model|
      model.joins(:sub_agent)
           .where.not(sub_agent_id: nil)
           .group("CONCAT(sub_agents.first_name, ' ', sub_agents.last_name)")
           .sum(:sub_agent_commission_amount)
           .each do |name, commission|
        agent_commissions[name] = (agent_commissions[name] || 0) + commission.to_f
      end
    end

    agent_commissions
  rescue => e
    Rails.logger.error "Error calculating agent commission: #{e.message}"
    {}
  end

  def calculate_agent_customer_data
    # Calculate customer counts for each agent to avoid DB calls in view
    agent_customers = {}

    # Process each sub agent and calculate their customer metrics
    SubAgent.includes(:customers, :health_insurances, :life_insurances, :motor_insurances).each do |sub_agent|
      agent_name = "#{sub_agent.first_name} #{sub_agent.last_name}"

      # Direct customer count
      customer_count = sub_agent.customers.count

      # Unique customers from each insurance type
      health_customers = sub_agent.health_insurances.distinct.count(:customer_id)
      life_customers = sub_agent.life_insurances.distinct.count(:customer_id)
      motor_customers = sub_agent.motor_insurances.distinct.count(:customer_id)

      # Use the maximum as the customer count (accounts for overlap)
      max_customers = [customer_count, health_customers, life_customers, motor_customers].max

      agent_customers[agent_name] = max_customers if max_customers > 0
    end

    agent_customers
  rescue => e
    Rails.logger.error "Error calculating agent customer data: #{e.message}"
    {}
  end

  def calculate_conversion_rate
    total_leads = Lead.count
    converted = Lead.where(current_stage: 'converted').count

    return 0 if total_leads == 0
    ((converted.to_f / total_leads.to_f) * 100).round(1)
  rescue => e
    Rails.logger.error "Error calculating conversion rate: #{e.message}"
    0
  end

  def calculate_avg_policy_value
    # Calculate average policy value across all insurance types
    return 0 if @total_policies == 0

    total_premium = @total_premium || 0
    (total_premium.to_f / @total_policies.to_f).round(0)
  rescue => e
    Rails.logger.error "Error calculating average policy value: #{e.message}"
    0
  end

  def calculate_customer_retention
    # Calculate customer retention rate based on customers with multiple policies
    total_customers = Customer.count
    return 0 if total_customers == 0

    # Count customers with more than one policy across all insurance types
    customers_with_multiple_policies = Customer.joins(
      "LEFT JOIN health_insurances ON health_insurances.customer_id = customers.id " +
      "LEFT JOIN life_insurances ON life_insurances.customer_id = customers.id " +
      "LEFT JOIN motor_insurances ON motor_insurances.customer_id = customers.id"
    ).group('customers.id')
     .having('COUNT(health_insurances.id) + COUNT(life_insurances.id) + COUNT(motor_insurances.id) > 1')
     .count.keys.length

    ((customers_with_multiple_policies.to_f / total_customers.to_f) * 100).round(1)
  rescue => e
    Rails.logger.error "Error calculating customer retention: #{e.message}"
    0
  end

  def calculate_lead_conversion_funnel
    {
      'Lead Generated'           => Lead.where(current_stage: 'lead_generated').count,
      'Consultation Scheduled'   => Lead.where(current_stage: 'consultation_scheduled').count,
      'One on One'               => Lead.where(current_stage: 'one_on_one').count,
      'Follow Up'                => Lead.where(current_stage: %w[follow_up re_follow_up]).count,
      'Converted'                => Lead.where(current_stage: 'converted').count
    }
  rescue => e
    Rails.logger.error "Error calculating lead conversion funnel: #{e.message}"
    { 'Lead Generated' => 0, 'Consultation Scheduled' => 0, 'One on One' => 0, 'Follow Up' => 0, 'Converted' => 0 }
  end

  def calculate_lead_stage_distribution
    {
      'Lead Generated'         => Lead.where(current_stage: 'lead_generated').count,
      'Consultation Scheduled' => Lead.where(current_stage: 'consultation_scheduled').count,
      'One on One'             => Lead.where(current_stage: 'one_on_one').count,
      'Follow Up'              => Lead.where(current_stage: %w[follow_up re_follow_up]).count,
      'Follow Up Successful'   => Lead.where(current_stage: 'follow_up_successful').count,
      'Follow Up Unsuccessful' => Lead.where(current_stage: 'follow_up_unsuccessful').count,
      'Not Interested'         => Lead.where(current_stage: 'not_interested').count,
      'Converted'              => Lead.where(current_stage: 'converted').count,
      'Lead Closed'            => Lead.where(current_stage: 'lead_closed').count
    }
  rescue => e
    Rails.logger.error "Error calculating lead stage distribution: #{e.message}"
    { 'Lead Generated' => 0, 'Consultation Scheduled' => 0, 'One on One' => 0, 'Follow Up' => 0,
      'Follow Up Successful' => 0, 'Follow Up Unsuccessful' => 0, 'Not Interested' => 0,
      'Converted' => 0, 'Lead Closed' => 0 }
  end

  def calculate_customer_location
    # Calculate customer distribution by location (city/state)
    location_data = {}

    # Group customers by city or state, whichever is available
    Customer.group(:city).count.each do |city, count|
      next if city.blank?
      location_data[city.to_s.titleize] = count
    end

    # If no city data, try state
    if location_data.empty?
      Customer.group(:state).count.each do |state, count|
        next if state.blank?
        location_data[state.to_s.titleize] = count
      end
    end

    # If still no data, provide a default
    if location_data.empty?
      location_data = { 'Unknown' => Customer.count }
    end

    location_data
  rescue => e
    Rails.logger.error "Error calculating customer location: #{e.message}"
    { 'Unknown' => Customer.count }
  end

  def calculate_customer_acquisition_trend
    start_date = 11.months.ago.beginning_of_month
    raw_counts = Customer
      .where(created_at: start_date.beginning_of_day..Time.current.end_of_day)
      .group("DATE_TRUNC('month', created_at)")
      .count

    counts_by_month = raw_counts.each_with_object({}) do |(ts, cnt), h|
      h[ts.to_date.strftime('%Y-%m')] = cnt
    end

    trend_data = {}
    12.times do |i|
      month_date = (Date.current - i.months).beginning_of_month
      trend_data[month_date.strftime('%b %Y')] = counts_by_month[month_date.strftime('%Y-%m')] || 0
    end
    trend_data.to_a.reverse.to_h
  rescue => e
    Rails.logger.error "Error calculating customer acquisition trend: #{e.message}"
    {
      'Jan 2024' => 0,
      'Feb 2024' => 0,
      'Mar 2024' => 0,
      'Apr 2024' => 0,
      'May 2024' => 0,
      'Jun 2024' => 0,
      'Jul 2024' => 0,
      'Aug 2024' => 0,
      'Sep 2024' => 0,
      'Oct 2024' => 0,
      'Nov 2024' => 0,
      'Dec 2024' => 0
    }
  end

  def calculate_premium_revenue_trend
    start_date = 11.months.ago.beginning_of_month.to_date
    range_date = start_date..Date.current
    to_key     = ->(ts) { ts.to_date.strftime('%Y-%m') }

    h_sums = HealthInsurance.where(DRWISE).where(policy_start_date: range_date)
                            .group("DATE_TRUNC('month', policy_start_date)").sum(:net_premium)
                            .transform_keys { |k| to_key.(k) }
    l_sums = LifeInsurance.where(DRWISE).where(policy_start_date: range_date)
                          .group("DATE_TRUNC('month', policy_start_date)").sum(:net_premium)
                          .transform_keys { |k| to_key.(k) }
    m_sums = (MotorInsurance.where(DRWISE).where(policy_start_date: range_date)
                            .group("DATE_TRUNC('month', policy_start_date)").sum(:net_premium)
                            .transform_keys { |k| to_key.(k) } rescue {})

    trend_data = {}
    12.times do |i|
      month_date = (Date.current - i.months).beginning_of_month
      k = month_date.strftime('%Y-%m')
      total = (h_sums[k] || 0) + (l_sums[k] || 0) + (m_sums[k] || 0)
      trend_data[month_date.strftime('%b %Y')] = total.round(0)
    end
    trend_data.to_a.reverse.to_h
  rescue => e
    Rails.logger.error "Error calculating premium revenue trend: #{e.message}"
    {}
  end

  def calculate_active_customers
    # Count customers who have made policies in the last 6 months or are marked as active
    recent_policy_customers = Customer.joins(
      "LEFT JOIN health_insurances ON health_insurances.customer_id = customers.id " +
      "LEFT JOIN life_insurances ON life_insurances.customer_id = customers.id " +
      "LEFT JOIN motor_insurances ON motor_insurances.customer_id = customers.id"
    ).where(
      "health_insurances.created_at > ? OR life_insurances.created_at > ? OR motor_insurances.created_at > ? OR customers.status = true",
      6.months.ago, 6.months.ago, 6.months.ago
    ).distinct.count

    recent_policy_customers
  rescue => e
    Rails.logger.error "Error calculating active customers: #{e.message}"
    Customer.where(status: true).count rescue Customer.count
  end

  def calculate_converted_leads
    # Count leads that have been converted to customers with policies
    Lead.where(current_stage: ['policy_created', 'converted']).count
  rescue => e
    Rails.logger.error "Error calculating converted leads: #{e.message}"
    0
  end

  def calculate_new_leads
    # Count leads created in the last 7 days
    Lead.where('created_at >= ?', 7.days.ago).count
  rescue => e
    Rails.logger.error "Error calculating new leads: #{e.message}"
    0
  end

  def calculate_support_tickets
    # Count open support tickets (assuming you have a helpdesk model)
    if defined?(Helpdesk)
      Helpdesk.where(status: ['open', 'in_progress']).count
    elsif defined?(ClientRequest)
      ClientRequest.where(status: ['pending', 'in_progress']).count
    else
      # Default fallback
      0
    end
  rescue => e
    Rails.logger.error "Error calculating support tickets: #{e.message}"
    0
  end

  def calculate_docs_pending
    # Count pending documents across different models
    pending_count = 0

    # Check if Document model exists and count pending documents
    if defined?(Document)
      pending_count += Document.where(status: 'pending').count rescue 0
    end

    # Alternative: count policies without required documents
    # This is a placeholder - adjust based on your document requirements
    health_without_docs = HealthInsurance.left_joins(:documents).where(documents: { id: nil }).count rescue 0
    life_without_docs = LifeInsurance.left_joins(:documents).where(documents: { id: nil }).count rescue 0
    motor_without_docs = MotorInsurance.left_joins(:documents).where(documents: { id: nil }).count rescue 0

    pending_count + health_without_docs + life_without_docs + motor_without_docs
  rescue => e
    Rails.logger.error "Error calculating docs pending: #{e.message}"
    0
  end

  def calculate_claims_processing
    # Count claims being processed (assuming you have a claims model)
    if defined?(Claim)
      Claim.where(status: ['submitted', 'under_review', 'processing']).count
    else
      # Alternative: count policies with recent claims activity
      # This is a placeholder - adjust based on your claims system
      0
    end
  rescue => e
    Rails.logger.error "Error calculating claims processing: #{e.message}"
    0
  end

  def calculate_client_requests_count
    # Count active client requests
    if defined?(ClientRequest)
      ClientRequest.where(status: ['pending', 'in_progress']).count
    elsif defined?(Helpdesk)
      Helpdesk.where(status: ['open', 'in_progress']).count
    else
      # Alternative: count recent customer communications
      # This is a placeholder - adjust based on your system
      5
    end
  rescue => e
    Rails.logger.error "Error calculating client requests: #{e.message}"
    0
  end

  def calculate_investor_status_distribution
    # nil status is treated as active (default)
    active_count = Investor.where(status: [0, nil]).count
    inactive_count = Investor.where(status: 1).count
    { 'Active' => active_count, 'Inactive' => inactive_count }
  rescue => e
    Rails.logger.error "Error calculating investor status distribution: #{e.message}"
    { 'Active' => 0, 'Inactive' => 0 }
  end

  def calculate_top_investors_by_ambassadors
    return {} unless Distributor.column_names.include?('investor_id')

    result = {}
    Investor.joins("LEFT JOIN distributors ON distributors.investor_id = investors.id")
            .group('investors.id, investors.first_name, investors.last_name')
            .select('investors.id, investors.first_name, investors.last_name, COUNT(distributors.id) as ambassador_count')
            .order('ambassador_count DESC')
            .limit(10)
            .each do |inv|
      name = "#{inv.first_name} #{inv.last_name}".strip
      result[name] = inv.ambassador_count.to_i
    end
    result
  rescue => e
    Rails.logger.error "Error calculating top investors by ambassadors: #{e.message}"
    {}
  end

  def calculate_top_investors_by_commission
    investor_commissions = {}
    [HealthInsurance, MotorInsurance].each do |model|
      model.where.not(investor_id: nil)
           .joins("JOIN investors ON investors.id = #{model.table_name}.investor_id")
           .group("CONCAT(investors.first_name, ' ', investors.last_name)")
           .sum(:investor_commission_amount)
           .each do |name, commission|
        investor_commissions[name] = (investor_commissions[name] || 0) + commission.to_f
      end
    end
    investor_commissions.sort_by { |_, v| -v }.first(10).to_h
  rescue => e
    Rails.logger.error "Error calculating top investors by commission: #{e.message}"
    {}
  end

  def fetch_analytics_card_records(metric)
    start_date = @filter_start_date
    end_date   = @filter_end_date
    dt_start   = start_date.beginning_of_day
    dt_end     = end_date.end_of_day
    range      = start_date..end_date

    case metric
    when 'customers'
      Customer.where(created_at: dt_start..dt_end).order(created_at: :desc).map do |c|
        { type: 'Customer', name: c.display_name, created_at: c.created_at.strftime('%d-%m-%Y'),
          city: c.city.to_s, phone: c.mobile.to_s }
      end
    when 'policies', 'premium'
      analytics_collect_policies(range)
    when 'leads'
      Lead.where(created_at: dt_start..dt_end).order(created_at: :desc).map do |l|
        { type: 'Lead', name: l.name.to_s, stage: l.current_stage.to_s.humanize,
          created_at: l.created_at.strftime('%d-%m-%Y') }
      end
    when 'investors'
      Investor.order(first_name: :asc, last_name: :asc).map do |i|
        { type: 'Investor', name: i.display_name.to_s, created_at: i.created_at.strftime('%d-%m-%Y') }
      end
    when 'affiliates'
      SubAgent.order(created_at: :desc).map do |a|
        { type: 'Affiliate', name: "#{a.first_name} #{a.last_name}".strip,
          created_at: a.created_at.strftime('%d-%m-%Y'), status: a.status.to_s }
      end
    else
      []
    end
  rescue => e
    Rails.logger.error "analytics card_detail error: #{e.message}"
    []
  end

  def analytics_collect_policies(range)
    policies = []
    HealthInsurance.where(DRWISE).where(policy_start_date: range).includes(:customer).order(policy_start_date: :desc).each do |p|
      policies << analytics_format_policy(p, 'Health', 'health')
    end
    LifeInsurance.where(DRWISE).where(policy_start_date: range).includes(:customer).order(policy_start_date: :desc).each do |p|
      policies << analytics_format_policy(p, 'Life', 'life')
    end
    begin
      MotorInsurance.where(DRWISE).where(policy_start_date: range).includes(:customer).order(policy_start_date: :desc).each do |p|
        policies << analytics_format_policy(p, 'Motor', 'motor')
      end
    rescue; end
    begin
      OtherInsurance.where(DRWISE).where(policy_start_date: range).includes(:customer).order(policy_start_date: :desc).each do |p|
        policies << analytics_format_policy(p, 'Other', 'other')
      end
    rescue; end
    policies.sort_by { |p| [p[:policy_start_date_raw] || '0000-00-00', p[:created_at_raw] || '0000-00-00'] }.reverse
  end

  def analytics_format_policy(p, type, route_key)
    { type: type,
      policy_number: p.policy_number.to_s,
      policy_link: "/admin/insurance/#{route_key}/#{p.id}",
      drwise: p.is_admin_added == true && p.is_customer_added == false && p.is_agent_added == false,
      customer: p.customer&.display_name || 'Unknown',
      policy_start_date: p.policy_start_date&.strftime('%d-%m-%Y'),
      policy_start_date_raw: p.policy_start_date.to_s,
      policy_end_date: p.policy_end_date&.strftime('%d-%m-%Y'),
      created_at: p.created_at.strftime('%d-%m-%Y'),
      created_at_raw: p.created_at.strftime('%Y-%m-%d'),
      net_premium: p.net_premium.to_f.round(2),
      total_premium: p.total_premium.to_f.round(2) }
  end
end