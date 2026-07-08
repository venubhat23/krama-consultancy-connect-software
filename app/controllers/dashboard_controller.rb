class DashboardController < ApplicationController
  skip_load_and_authorize_resource
  before_action :redirect_ambassador_users

  def index
    authorize! :read, :dashboard
    load_dashboard_data
  end

  def beautiful
    authorize! :read, :dashboard
    load_dashboard_data
    render 'beautiful_dashboard', layout: false
  end

  def ultra
    authorize! :read, :dashboard
    load_dashboard_data
    render 'ultra_attractive_dashboard', layout: false
  end

  def net_profit
    authorize! :read, :dashboard
    @start_date = params[:start_date].presence || Date.new(Date.current.year, 1, 1).strftime('%Y-%m-%d')
    @end_date   = params[:end_date].presence   || Date.current.strftime('%Y-%m-%d')
  end

  def avg_policy_value
    authorize! :read, :dashboard
  end

  def card_detail
    authorize! :read, :dashboard
    start_date = params[:start_date].present? ? (Date.parse(params[:start_date]) rescue Date.new(Date.current.year, 1, 1)) : Date.new(Date.current.year, 1, 1)
    end_date   = params[:end_date].present?   ? (Date.parse(params[:end_date])   rescue Date.new(Date.current.year, 12, 31)) : Date.new(Date.current.year, 12, 31)
    metric     = params[:metric].to_s

    records = fetch_card_detail_records(metric, start_date, end_date)
    render json: { records: records, metric: metric, count: records.size }
  rescue => e
    render json: { error: e.message }, status: 422
  end

  def stats
    authorize! :read, :dashboard

    # Use instant stats for API endpoints
    stats_data = DashboardTieredCacheService.fetch_stats(mode: :instant)

    render json: stats_data.merge({
      # API metadata
      cached: true,
      cache_type: stats_data[:cached_from] || 'tiered_cache',
      cache_age: stats_data[:cache_age_seconds] || 0,
      generated_at: Time.current.iso8601
    })
  rescue => e
    Rails.logger.error "Stats API failed: #{e.message}"
    render json: { error: 'Stats temporarily unavailable' }, status: 503
  end

  # Manual cache refresh endpoint
  def refresh_cache
    authorize! :read, :dashboard

    # Clear all cache tiers
    Rails.cache.clear
    Thread.current[:dashboard_tier_cache] = nil

    # Refresh materialized view
    DashboardInstantService.refresh_materialized_view!

    # Warm up cache in background
    DashboardCacheWarmerJob.perform_later

    load_dashboard_data

    respond_to do |format|
      format.html { redirect_to root_path, notice: 'Dashboard cache refreshed!' }
      format.json { render json: { success: true, message: 'Cache refreshed' } }
    end
  end

  # Performance monitoring endpoint
  def performance
    authorize! :read, :dashboard

    report = DashboardPerformanceMonitor.performance_report

    render json: {
      performance: report,
      health_check: DashboardPerformanceMonitor.health_check,
      timestamp: Time.current.iso8601
    }
  end

  # Health check endpoint for monitoring
  def health
    health_status = DashboardPerformanceMonitor.health_check

    status_code = health_status[:overall_status] == :healthy ? 200 : 503

    render json: health_status, status: status_code
  end

  private

  def redirect_ambassador_users
    if current_user&.ambassador?
      redirect_to ambassador_dashboard_path
    elsif current_user&.investor?
      redirect_to investor_profit_summary_path
    end
  end

  def load_dashboard_data
    start_time = Time.current

    # Get date filter parameters (default to current year)
    current_year = Date.current.year

    if params[:financial_year].present?
      # Indian Financial Year: April 1 (year-1) to March 31 (year)
      fy = params[:financial_year].to_i.clamp(2000, 2100)
      @filter_financial_year = fy
      @filter_year = fy
      @filter_month = nil
      @filter_start_date = Date.new(fy - 1, 4, 1)
      @filter_end_date = Date.new(fy, 3, 31)
    else
      @filter_financial_year = nil
      @filter_year = params[:year].present? ? params[:year].to_i.clamp(2000, 2100) : current_year
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

      # If month is specified, filter by that month
      if @filter_month.present?
        @filter_start_date = Date.new(@filter_year, @filter_month, 1)
        @filter_end_date = @filter_start_date.end_of_month
      end
    end

    # Create cache key based on filter parameters; gen is bumped on any record change
    cache_gen = Rails.cache.read("dashboard_cache_gen") || "0"
    cache_key = "dashboard_data_#{cache_gen}_#{@filter_start_date}_#{@filter_end_date}_v7"

    # Try to get cached data first (5 minutes cache)
    filtered_data = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      get_filtered_dashboard_data(@filter_start_date, @filter_end_date)
    end

    # Load filter-independent data (always based on current date, not filter dates)
    # Cache this separately with shorter expiry since it's real-time data
    filter_independent_cache_key = "dashboard_filter_independent_#{Date.current}_v3"
    filter_independent_data = Rails.cache.fetch(filter_independent_cache_key, expires_in: 2.minutes) do
      load_filter_independent_data()
    end

    # Merge: filter_independent data is the base; filtered_data overrides matching keys
    # so filter-specific values (e.g. premium_revenue_trend) take precedence.
    filtered_data = filter_independent_data.merge(filtered_data)

    # Track performance
    DashboardPerformanceMonitor.track_dashboard_load(
      start_time: start_time,
      end_time: Time.current,
      cache_hit: Rails.cache.exist?(cache_key),
      data_source: Rails.cache.exist?(cache_key) ? 'cached_filtered_data' : 'filtered_data'
    )

    # Set instance variables from filtered data
    filtered_data.each { |key, value| instance_variable_set("@#{key}", value) }
  rescue => e
    Rails.logger.error "Dashboard data loading failed: #{e.message}"
    # Fallback to basic counts if ultra-fast service fails
    @total_customers = Customer.count
    @total_policies = 0
  end

  private

  def load_filter_independent_data
    # These sections should always show current real-time data, not filtered by date
    results = {}
    current_date = Date.current
    forty_five_days_from_now = current_date + 30.days

    # Renewal Alerts - always based on current date
    results[:renewal_due_count] = get_renewal_due_count(forty_five_days_from_now)
    results[:recently_expired_count] = get_recently_expired_count
    results[:renewal_status] = get_renewal_status_counts

    # Policy Alerts - always based on current date
    results[:policies_expiring_soon] = get_renewal_due_count(forty_five_days_from_now)
    results[:expired_this_month] = get_expired_this_month_count
    results[:renewal_opportunities] = get_renewal_opportunities_count

    # Birthdays & Anniversaries - always based on current date
    results[:upcoming_birthdays] = get_upcoming_birthdays
    results[:upcoming_anniversaries] = get_upcoming_anniversaries

    # Recent Activity - always shows latest activities
    results[:recent_policies] = get_recent_policies

    # Premium Revenue Trend - last 6 months from current date
    results[:premium_revenue_trend] = get_premium_revenue_trend_data

    # Keep backward compatibility
    results[:expired_policies_count] = results[:recently_expired_count]

    results
  rescue => e
    Rails.logger.error "Error loading filter-independent data: #{e.message}"
    {}
  end

  def get_upcoming_birthdays
    today = Date.current
    # Fetch customers with a birth_date; compare month/day to the next 30 days
    Customer.where(status: true)
            .where.not(birth_date: nil)
            .select(:id, :first_name, :last_name, :company_name, :customer_type, :mobile, :birth_date)
            .order(Arel.sql("EXTRACT(MONTH FROM birth_date), EXTRACT(DAY FROM birth_date)"))
            .select do |c|
              bday = c.birth_date
              # Birthday this year or next (wrap around year boundary)
              this_year = Date.new(today.year, bday.month, bday.day) rescue nil
              next_year = Date.new(today.year + 1, bday.month, bday.day) rescue nil
              upcoming = (this_year && this_year >= today) ? this_year : next_year
              upcoming && (upcoming - today).to_i <= 30
            end
  rescue => e
    Rails.logger.error "Error fetching upcoming birthdays: #{e.message}"
    []
  end

  def get_upcoming_anniversaries
    today = Date.current
    Customer.where(status: true)
            .where.not(anniversary_date: nil)
            .select(:id, :first_name, :last_name, :company_name, :customer_type, :mobile, :anniversary_date)
            .order(Arel.sql("EXTRACT(MONTH FROM anniversary_date), EXTRACT(DAY FROM anniversary_date)"))
            .select do |c|
              ann = c.anniversary_date
              this_year = Date.new(today.year, ann.month, ann.day) rescue nil
              next_year = Date.new(today.year + 1, ann.month, ann.day) rescue nil
              upcoming = (this_year && this_year >= today) ? this_year : next_year
              upcoming && (upcoming - today).to_i <= 30
            end
  rescue => e
    Rails.logger.error "Error fetching upcoming anniversaries: #{e.message}"
    []
  end

  def get_premium_revenue_trend_data
    # Get last 6 months of premium data from current date
    end_date = Date.current.end_of_month
    start_date = end_date - 5.months

    trend_data = []
    6.times do |i|
      month_start = (end_date - i.months).beginning_of_month
      month_end = (end_date - i.months).end_of_month

      monthly_premium = get_premium_for_period(month_start, month_end)
      trend_data.unshift({
        month: month_start.strftime('%b %Y'),
        amount: monthly_premium
      })
    end

    trend_data
  rescue => e
    Rails.logger.error "Error calculating premium trend: #{e.message}"
    []
  end

  def get_filtered_dashboard_data(start_date, end_date)
    # Execute all database queries with date filtering - optimized version
    results = {}

    h_dr = dr_filter(:health_insurances)
    l_dr = dr_filter(:life_insurances)
    m_dr = dr_filter(:motor_insurances)

    # For timestamp (created_at) columns use exclusive upper bound to include full last day.
    # For date (policy_start_date) columns BETWEEN is fine.
    next_day = end_date + 1.day

    # All counts filtered by the selected date range
    count_results = ActiveRecord::Base.connection.execute("
      SELECT 'total_customers' as metric, COUNT(*) as count FROM customers
      WHERE created_at >= '#{start_date}' AND created_at < '#{next_day}'
      UNION ALL
      SELECT 'active_customers', COUNT(*) FROM customers
      WHERE status = true AND created_at >= '#{start_date}' AND created_at < '#{next_day}'
      UNION ALL
      SELECT 'total_ambassadors', COUNT(*) FROM distributors
      WHERE created_at >= '#{start_date}' AND created_at < '#{next_day}'
      UNION ALL
      SELECT 'total_leads', COUNT(*) FROM leads
      WHERE created_at >= '#{start_date}' AND created_at < '#{next_day}'
      UNION ALL
      SELECT 'converted_leads', COUNT(*) FROM leads
      WHERE current_stage = 'converted' AND created_at >= '#{start_date}' AND created_at < '#{next_day}'
      UNION ALL
      SELECT 'health_count', COUNT(*) FROM health_insurances
      WHERE TRUE #{h_dr} AND policy_start_date BETWEEN '#{start_date}' AND '#{end_date}'
      UNION ALL
      SELECT 'life_count', COUNT(*) FROM life_insurances
      WHERE TRUE #{l_dr} AND policy_start_date BETWEEN '#{start_date}' AND '#{end_date}'
    ")

    # Process count results
    count_results.each do |row|
      results[row['metric'].to_sym] = row['count']
    end

    # Handle optional tables that might not exist - simplified for performance
    results[:motor_count] = (dr_scope(MotorInsurance).where(policy_start_date: start_date..end_date).count rescue 0)
    results[:other_count] = (dr_scope(OtherInsurance).where(policy_start_date: start_date..end_date).count rescue 0)

    # Active affiliates = all sub-agents with at least one policy (not filtered by date)
    results[:total_affiliates] = calculate_active_affiliates_with_policies

    # Calculate derived values
    results[:inactive_customers] = results[:total_customers].to_i - results[:active_customers].to_i
    results[:lead_conversion_percentage] = results[:total_leads].to_i > 0 ? ((results[:converted_leads].to_f / results[:total_leads].to_f) * 100).round(2) : 0

    # Filtered totals for the selected period (policies filtered by policy_start_date)
    results[:total_policies] = results[:health_count].to_i + results[:life_count].to_i +
                               results[:motor_count].to_i + results[:other_count].to_i

    # Premium data for the filtered period — use AR to stay consistent with analytics
    results[:total_premium_collected] = get_premium_for_period(start_date, end_date)
    results[:total_premium]           = results[:total_premium_collected]
    results[:total_sum_insured]       = get_sum_insured_for_period(start_date, end_date)

    # Pending leads count for the period — all stages except terminal ones
    active_lead_stages = ['lead_generated', 'consultation_scheduled', 'one_on_one', 'follow_up',
                          'follow_up_successful', 'follow_up_unsuccessful', 're_follow_up']
    results[:pending_leads] = Lead.where(current_stage: active_lead_stages)
                                  .where(created_at: start_date.beginning_of_day..end_date.end_of_day).count

    # Renewal and expiry data are now loaded in load_filter_independent_data
    # to ensure they always show current real-time status regardless of filter
    # These lines are commented out as they're now handled separately:
    # results[:renewal_due_count] = get_renewal_due_count_for_period(start_date, end_date)
    # results[:expired_policies_count] = get_expired_policies_count_for_period(start_date, end_date)
    # results[:renewal_status] = get_renewal_status_counts_for_period(start_date, end_date)

    # Payout data for the period
    payout_data = get_optimized_payout_data_for_period(start_date, end_date)
    results.merge!(
      pending_payouts: payout_data[:pending_amount],
      paid_payouts: payout_data[:paid_amount],
      total_payouts: payout_data[:total_amount]
    )

    # Calculate growth metrics for the period
    growth_metrics = calculate_growth_metrics_for_period(start_date, end_date)
    results.merge!(growth_metrics)

    # Recent activity data is now loaded in load_filter_independent_data
    # to always show the latest activities regardless of filter
    # results[:recent_policies] = get_recent_policies_for_period(start_date, end_date)
    results[:recent_leads] = get_recent_leads_for_period(start_date, end_date)

    # Build monthly revenue trend for the filtered period so the chart reflects
    # the selected date range rather than always showing "last 6 months".
    results[:premium_revenue_trend] = build_period_monthly_trend(start_date, end_date)

    # Add missing variables that the dashboard expects
    # commissions_due = main-agent pending only, to match commission tracking page "Pending Transfers"
    results[:commissions_due] = CommissionPayout.where(payout_to: 'main_agent', status: 'pending').sum(:payout_amount).to_f
    results[:avg_policy_value] = results[:total_policies] > 0 ? (results[:total_premium_collected] / results[:total_policies]).round(0) : 0

    # Total profit: recalculate per-table to handle schema differences across insurance types
    results[:total_profit] = calculate_total_profit_for_period(start_date, end_date)

    # Add filter information
    results[:filter_start_date] = start_date
    results[:filter_end_date] = end_date
    results[:filter_year] = start_date.year
    results[:filter_month] = start_date.month if start_date.month == end_date.month

    results
  end

  # Helper methods for filtered data
  def get_renewal_due_count_for_period(start_date, end_date)
    forty_five_days_from_end = end_date + 45.days
    h_dr = dr_filter(:health_insurances)
    l_dr = dr_filter(:life_insurances)

    sql = "
      SELECT COUNT(*) as count FROM (
        SELECT id FROM health_insurances WHERE TRUE #{h_dr} AND policy_start_date BETWEEN '#{start_date}' AND '#{end_date}' AND policy_end_date BETWEEN '#{end_date}' AND '#{forty_five_days_from_end}'
        UNION ALL
        SELECT id FROM life_insurances WHERE TRUE #{l_dr} AND policy_start_date BETWEEN '#{start_date}' AND '#{end_date}' AND policy_end_date BETWEEN '#{end_date}' AND '#{forty_five_days_from_end}'
      ) as renewals
    "

    count = ActiveRecord::Base.connection.execute(sql).first['count'].to_i

    begin
      count += dr_scope(MotorInsurance).where(policy_start_date: start_date..end_date, policy_end_date: end_date..forty_five_days_from_end).count
    rescue; end

    begin
      count += dr_scope(OtherInsurance).where(policy_start_date: start_date..end_date, policy_end_date: end_date..forty_five_days_from_end).count
    rescue; end

    count
  end

  def get_expired_policies_count_for_period(start_date, end_date)
    h_dr = dr_filter(:health_insurances)
    l_dr = dr_filter(:life_insurances)

    sql = "
      SELECT COUNT(*) as count FROM (
        SELECT id FROM health_insurances WHERE TRUE #{h_dr} AND policy_start_date BETWEEN '#{start_date}' AND '#{end_date}' AND policy_end_date < '#{end_date}'
        UNION ALL
        SELECT id FROM life_insurances WHERE TRUE #{l_dr} AND policy_start_date BETWEEN '#{start_date}' AND '#{end_date}' AND policy_end_date < '#{end_date}'
      ) as expired
    "

    count = ActiveRecord::Base.connection.execute(sql).first['count'].to_i

    begin
      count += dr_scope(MotorInsurance).where(policy_start_date: start_date..end_date).where('policy_end_date < ?', end_date).count
    rescue; end

    begin
      count += dr_scope(OtherInsurance).where(policy_start_date: start_date..end_date).where('policy_end_date < ?', end_date).count
    rescue; end

    count
  end

  def get_optimized_payout_data_for_period(start_date, end_date)
    # Show all pending commissions regardless of date (pending = still owed)
    # Paid/total filtered by payout_date for the period
    commission_pending = CommissionPayout.where(status: 'pending').sum(:payout_amount) || 0
    commission_paid    = CommissionPayout.where(status: 'paid', payout_date: start_date..end_date).sum(:payout_amount) || 0
    commission_total   = CommissionPayout.where(payout_date: start_date..end_date).sum(:payout_amount) || 0

    distributor_pending = 0
    distributor_paid    = 0
    distributor_total   = 0

    begin
      if ActiveRecord::Base.connection.table_exists?('distributor_payouts')
        distributor_pending = DistributorPayout.where(status: 'pending').sum(:payout_amount) || 0
        distributor_paid    = DistributorPayout.where(status: 'paid', payout_date: start_date..end_date).sum(:payout_amount) || 0
        distributor_total   = DistributorPayout.where(payout_date: start_date..end_date).sum(:payout_amount) || 0
      end
    rescue
    end

    {
      pending_amount: commission_pending + distributor_pending,
      paid_amount: commission_paid + distributor_paid,
      total_amount: commission_total + distributor_total
    }
  end

  def get_renewal_status_counts_for_period(start_date, end_date)
    renewed_count = 0

    begin
      renewed_count += dr_scope(HealthInsurance).where(policy_start_date: start_date..end_date, policy_type: 'Renewal').count
      renewed_count += dr_scope(LifeInsurance).where(policy_start_date: start_date..end_date, policy_type: 'Renewal').count
      renewed_count += (dr_scope(MotorInsurance).where(policy_start_date: start_date..end_date, policy_type: 'Renewal').count rescue 0)
    rescue => e
      Rails.logger.error "Error calculating renewal status for period: #{e.message}"
      renewed_count = 0
    end

    {
      'Renewed' => renewed_count,
      'Pending' => get_renewal_due_count_for_period(start_date, end_date),
      'Expired' => get_expired_policies_count_for_period(start_date, end_date)
    }
  end

  def get_recent_policies_for_period(start_date, end_date)
    sql = "
      SELECT * FROM (
        SELECT
          'Health Insurance' as policy_type,
          h.policy_number,
          h.net_premium as total_premium,
          h.created_at,
          CONCAT(COALESCE(c.first_name, ''), ' ', COALESCE(c.last_name, '')) as customer_name
        FROM health_insurances h
        LEFT JOIN customers c ON h.customer_id = c.id
        WHERE h.policy_start_date BETWEEN '#{start_date}' AND '#{end_date}'
        ORDER BY h.policy_start_date DESC
        LIMIT 5
      ) AS health
      UNION ALL
      SELECT * FROM (
        SELECT
          'Life Insurance' as policy_type,
          l.policy_number,
          l.net_premium as total_premium,
          l.created_at,
          CONCAT(COALESCE(c.first_name, ''), ' ', COALESCE(c.last_name, '')) as customer_name
        FROM life_insurances l
        LEFT JOIN customers c ON l.customer_id = c.id
        WHERE l.policy_start_date BETWEEN '#{start_date}' AND '#{end_date}'
        ORDER BY l.policy_start_date DESC
        LIMIT 5
      ) AS life
    "

    # Add motor insurance if it exists
    begin
      if ActiveRecord::Base.connection.table_exists?('motor_insurances')
        sql += "
          UNION ALL
          SELECT * FROM (
            SELECT
              'Motor Insurance' as policy_type,
              m.policy_number,
              m.net_premium as total_premium,
              m.created_at,
              CONCAT(COALESCE(c.first_name, ''), ' ', COALESCE(c.last_name, '')) as customer_name
            FROM motor_insurances m
            LEFT JOIN customers c ON m.customer_id = c.id
            WHERE m.policy_start_date BETWEEN '#{start_date}' AND '#{end_date}'
            ORDER BY m.policy_start_date DESC
            LIMIT 5
          ) AS motor
        "
      end
    rescue
    end

    sql += " ORDER BY created_at DESC LIMIT 10"

    results = ActiveRecord::Base.connection.execute(sql)
    results.map do |row|
      {
        type: row['policy_type'],
        customer: row['customer_name'] || 'Unknown',
        policy_number: row['policy_number'],
        premium: row['total_premium'].to_f,
        date: row['created_at']
      }
    end
  rescue => e
    Rails.logger.error "Error fetching recent policies for period: #{e.message}"
    []
  end

  def get_recent_leads_for_period(start_date, end_date)
    Lead.select(:id, :lead_id, :name, :current_stage, :created_at)
        .where(created_at: start_date..end_date)
        .order(created_at: :desc)
        .limit(10)
  rescue => e
    Rails.logger.error "Error fetching recent leads for period: #{e.message}"
    []
  end

  def calculate_growth_metrics_for_period(start_date, end_date)
    # Compare current period with previous period of same duration.
    # Use .to_i to get integer days; calling .days twice overflows PostgreSQL timestamps.
    min_valid_date = Date.new(1900, 1, 1)
    days_in_period = (end_date - start_date).to_i

    previous_end   = start_date - 1.day
    previous_start = [start_date - days_in_period, min_valid_date].max

    # If previous_start is before minimum valid date, adjust the period
    if previous_start <= min_valid_date
      previous_start = min_valid_date
      # Keep the same duration if possible, otherwise use what's available
      if previous_end < min_valid_date
        # No valid previous period available, use same period for comparison
        previous_start = start_date
        previous_end = end_date
      end
    end

    # Current period data — insurance uses policy_start_date; customers/leads/affiliates use created_at
    current_customers = Customer.where(created_at: start_date.beginning_of_day..end_date.end_of_day).count
    current_policies = get_policies_count_for_period(start_date, end_date)
    current_premium = get_premium_for_period(start_date, end_date)
    current_affiliates = SubAgent.where(created_at: start_date.beginning_of_day..end_date.end_of_day).count
    current_ambassadors = Distributor.where(created_at: start_date.beginning_of_day..end_date.end_of_day).count
    current_leads = Lead.where(created_at: start_date.beginning_of_day..end_date.end_of_day).count

    # Previous period data
    previous_customers = Customer.where(created_at: previous_start.beginning_of_day..previous_end.end_of_day).count
    previous_policies = get_policies_count_for_period(previous_start, previous_end)
    previous_premium = get_premium_for_period(previous_start, previous_end)
    previous_affiliates = SubAgent.where(created_at: previous_start.beginning_of_day..previous_end.end_of_day).count
    previous_ambassadors = Distributor.where(created_at: previous_start.beginning_of_day..previous_end.end_of_day).count
    previous_leads = Lead.where(created_at: previous_start.beginning_of_day..previous_end.end_of_day).count

    # Calculate growth percentages
    {
      customer_growth: calculate_percentage_change(current_customers, previous_customers),
      policy_growth: calculate_percentage_change(current_policies, previous_policies),
      premium_growth: calculate_percentage_change(current_premium, previous_premium),
      affiliate_growth: calculate_percentage_change(current_affiliates, previous_affiliates),
      ambassador_growth: calculate_percentage_change(current_ambassadors, previous_ambassadors),
      lead_growth: calculate_percentage_change(current_leads, previous_leads),
      conversion_rate: current_leads > 0 ? ((Lead.where(current_stage: 'converted').where(created_at: start_date.beginning_of_day..end_date.end_of_day).count.to_f / current_leads) * 100).round(1) : 0,
      avg_policy_value: current_policies > 0 ? (current_premium / current_policies).round(0) : 0,
      monthly_recurring_revenue: (current_premium / 12.0).round(0)
    }
  end

  # Optimized helper methods to avoid N+1 queries

  def get_all_dashboard_data
    # Execute all database queries in parallel/batch to minimize load time
    # Use pluck and select to reduce memory usage

    # Use database connection pool for parallel queries
    results = {}

    # Batch count queries using single SQL with UNION for better performance
    count_results = ActiveRecord::Base.connection.execute("
      SELECT 'total_customers' as metric, COUNT(*) as count FROM customers
      UNION ALL
      SELECT 'active_customers', COUNT(*) FROM customers WHERE status = true
      UNION ALL
      SELECT 'total_ambassadors', COUNT(*) FROM distributors
      UNION ALL
      SELECT 'total_leads', COUNT(*) FROM leads
      UNION ALL
      SELECT 'converted_leads', COUNT(*) FROM leads WHERE current_stage = 'converted'
      UNION ALL
      SELECT 'health_count', COUNT(*) FROM health_insurances WHERE 1=1
      UNION ALL
      SELECT 'life_count', COUNT(*) FROM life_insurances WHERE 1=1
    ")

    # Process count results
    count_results.each do |row|
      results[row['metric'].to_sym] = row['count']
    end

    # Handle optional tables that might not exist
    results[:motor_count] = (MotorInsurance.count rescue 0)
    results[:other_count] = (OtherInsurance.count rescue 0)

    # Calculate active affiliates (only those with policies)
    results[:total_affiliates] = calculate_active_affiliates_with_policies

    # Calculate derived values
    results[:inactive_customers] = results[:total_customers].to_i - results[:active_customers].to_i
    results[:total_policies] = results[:health_count].to_i + results[:life_count].to_i + results[:motor_count].to_i + results[:other_count].to_i
    results[:lead_conversion_percentage] = results[:total_leads].to_i > 0 ? ((results[:converted_leads].to_f / results[:total_leads].to_f) * 100).round(2) : 0

    # Premium data - single query with UNION for better performance
    premium_results = ActiveRecord::Base.connection.execute("
      SELECT
        COALESCE(SUM(net_premium), 0) as total_premium,
        COALESCE(SUM(sum_insured), 0) as total_sum_insured
      FROM (
        SELECT net_premium, sum_insured FROM health_insurances WHERE 1=1
        UNION ALL
        SELECT net_premium, sum_insured FROM life_insurances WHERE 1=1
      ) as combined_insurance
    ").first

    results[:total_premium_collected] = (premium_results['total_premium'] || 0).to_f
    results[:total_sum_insured] = (premium_results['total_sum_insured'] || 0).to_f

    # Add motor insurance if table exists
    begin
      motor_data = MotorInsurance.select('COALESCE(SUM(net_premium), 0) as premium, COALESCE(SUM(sum_insured), 0) as sum').first
      results[:total_premium_collected] += motor_data.premium.to_f
      results[:total_sum_insured] += motor_data.sum.to_f
    rescue
      # Motor insurance table doesn't exist
    end

    # Pending leads count — all stages except terminal ones
    active_lead_stages = ['lead_generated', 'consultation_scheduled', 'one_on_one', 'follow_up',
                          'follow_up_successful', 'follow_up_unsuccessful', 're_follow_up']
    results[:pending_leads] = Lead.where(current_stage: active_lead_stages).count

    # Renewals and expired policies (date-based queries)
    forty_five_days_from_now = Date.current + 30.days
    results[:renewal_due_count] = get_renewal_due_count(forty_five_days_from_now)
    results[:expired_policies_count] = get_expired_policies_count
    results[:renewal_status] = get_renewal_status_counts

    # Payout data
    payout_data = get_optimized_payout_data
    results.merge!(
      pending_payouts: payout_data[:pending_amount],
      paid_payouts: payout_data[:paid_amount],
      total_payouts: payout_data[:total_amount]
    )

    # Calculate growth metrics
    growth_metrics = calculate_growth_metrics_data(results)
    results.merge!(growth_metrics)

    # Add recent activities data
    results[:recent_policies] = get_recent_policies
    results[:recent_leads] = get_recent_leads

    results
  end

  def get_optimized_policy_counts
    # Legacy method for backward compatibility
    {
      health_count: HealthInsurance.count,
      life_count: LifeInsurance.count,
      motor_count: (MotorInsurance.count rescue 0),
      other_count: (OtherInsurance.count rescue 0),
      total_count: HealthInsurance.count + LifeInsurance.count + (MotorInsurance.count rescue 0) + (OtherInsurance.count rescue 0)
    }
  end

  def get_optimized_premium_data
    # Simpler direct sum queries
    health_premium = HealthInsurance.sum(:net_premium) || 0
    life_premium = LifeInsurance.sum(:net_premium) || 0
    motor_premium = begin
      MotorInsurance.sum(:net_premium) || 0
    rescue
      0
    end

    health_sum = HealthInsurance.sum(:sum_insured) || 0
    life_sum = LifeInsurance.sum(:sum_insured) || 0
    motor_sum = begin
      MotorInsurance.sum(:sum_insured) || 0
    rescue
      0
    end

    {
      total_premium: health_premium + life_premium + motor_premium,
      total_sum_insured: health_sum + life_sum + motor_sum
    }
  end

  def get_renewal_due_count(forty_five_days_from_now)
    current_date = Date.current
    dr = dr_filter
    sql = "
      SELECT COUNT(*) as count FROM (
        SELECT id FROM health_insurances WHERE TRUE #{dr} AND policy_end_date BETWEEN '#{current_date}' AND '#{forty_five_days_from_now}'
        UNION ALL
        SELECT id FROM life_insurances WHERE TRUE #{dr} AND policy_end_date BETWEEN '#{current_date}' AND '#{forty_five_days_from_now}'
      ) as renewals
    "

    result = ActiveRecord::Base.connection.execute(sql)
    count = result.first['count'].to_i

    begin
      if ActiveRecord::Base.connection.table_exists?('motor_insurances')
        count += dr_scope(MotorInsurance).where('policy_end_date BETWEEN ? AND ?', Date.current, forty_five_days_from_now).count
      end
    rescue
    end

    begin
      if ActiveRecord::Base.connection.table_exists?('other_insurances')
        count += dr_scope(OtherInsurance).where('policy_end_date BETWEEN ? AND ?', Date.current, forty_five_days_from_now).count
      end
    rescue
    end

    count
  end

  def get_expired_policies_count
    current_date = Date.current
    dr = dr_filter
    sql = "
      SELECT COUNT(*) as count FROM (
        SELECT id FROM health_insurances WHERE TRUE #{dr} AND policy_end_date < '#{current_date}'
        UNION ALL
        SELECT id FROM life_insurances WHERE TRUE #{dr} AND policy_end_date < '#{current_date}'
      ) as expired
    "

    result = ActiveRecord::Base.connection.execute(sql)
    count = result.first['count'].to_i

    begin
      if ActiveRecord::Base.connection.table_exists?('motor_insurances')
        count += dr_scope(MotorInsurance).where('policy_end_date < ?', Date.current).count
      end
    rescue
    end

    begin
      if ActiveRecord::Base.connection.table_exists?('other_insurances')
        count += dr_scope(OtherInsurance).where('policy_end_date < ?', Date.current).count
      end
    rescue
    end

    count
  end

  def get_optimized_payout_data
    # Use single query to get all payout data at once
    commission_data = CommissionPayout
      .group(:status)
      .sum(:payout_amount)

    commission_pending = commission_data['pending'] || 0
    commission_paid = commission_data['paid'] || 0
    commission_total = CommissionPayout.sum(:payout_amount) || 0

    distributor_pending = 0
    distributor_paid = 0
    distributor_total = 0

    # Check if distributor payouts exist
    begin
      if ActiveRecord::Base.connection.table_exists?('distributor_payouts')
        distributor_data = DistributorPayout
          .group(:status)
          .sum(:payout_amount)

        distributor_pending = distributor_data['pending'] || 0
        distributor_paid = distributor_data['paid'] || 0
        distributor_total = DistributorPayout.sum(:payout_amount) || 0
      end
    rescue
    end

    {
      pending_amount: commission_pending + distributor_pending,
      paid_amount: commission_paid + distributor_paid,
      total_amount: commission_total + distributor_total
    }
  end

  def calculate_growth_metrics_data(results)
    # Get data for current month and last month
    current_month_start = Date.current.beginning_of_month
    last_month_start = 1.month.ago.beginning_of_month
    last_month_end = 1.month.ago.end_of_month

    # Current month data
    current_customers = Customer.where('created_at >= ?', current_month_start).count
    current_policies = get_policies_count_for_period(current_month_start, Date.current)
    current_premium = get_premium_for_period(current_month_start, Date.current)
    current_affiliates = SubAgent.where('created_at >= ?', current_month_start).count
    current_ambassadors = Distributor.where('created_at >= ?', current_month_start).count
    current_leads = Lead.where('created_at >= ?', current_month_start).count
    current_renewals = get_renewals_count_for_period(current_month_start, Date.current)
    current_payouts = get_payouts_for_period(current_month_start, Date.current)
    current_sum_insured = get_sum_insured_for_period(current_month_start, Date.current)

    # Last month data
    last_customers = Customer.where(created_at: last_month_start..last_month_end).count
    last_policies = get_policies_count_for_period(last_month_start, last_month_end)
    last_premium = get_premium_for_period(last_month_start, last_month_end)
    last_affiliates = SubAgent.where(created_at: last_month_start..last_month_end).count
    last_ambassadors = Distributor.where(created_at: last_month_start..last_month_end).count
    last_leads = Lead.where(created_at: last_month_start..last_month_end).count
    last_renewals = get_renewals_count_for_period(last_month_start, last_month_end)
    last_payouts = get_payouts_for_period(last_month_start, last_month_end)
    last_sum_insured = get_sum_insured_for_period(last_month_start, last_month_end)

    # Calculate growth percentages
    customer_growth = calculate_percentage_change(current_customers, last_customers)
    policy_growth = calculate_percentage_change(current_policies, last_policies)
    premium_growth = calculate_percentage_change(current_premium, last_premium)
    affiliate_growth = calculate_percentage_change(current_affiliates, last_affiliates)
    ambassador_growth = calculate_percentage_change(current_ambassadors, last_ambassadors)
    lead_growth = calculate_percentage_change(current_leads, last_leads)
    renewal_growth = calculate_percentage_change(current_renewals, last_renewals)
    payout_growth = calculate_percentage_change(current_payouts, last_payouts)
    sum_insured_growth = calculate_percentage_change(current_sum_insured, last_sum_insured)

    # Additional metrics
    conversion_rate = results[:total_leads] > 0 ? ((results[:converted_leads].to_f / results[:total_leads]) * 100).round(1) : 0
    avg_policy_value = results[:total_policies] > 0 ? (results[:total_premium_collected] / results[:total_policies]).round(0) : 0
    customer_retention = calculate_customer_retention_rate
    monthly_recurring_revenue = (results[:total_premium_collected] / 12.0).round(0)
    commissions_due = CommissionPayout.where(payout_to: 'main_agent', status: 'pending').sum(:payout_amount).to_f

    {
      customer_growth: customer_growth,
      policy_growth: policy_growth,
      premium_growth: premium_growth,
      affiliate_growth: affiliate_growth,
      ambassador_growth: ambassador_growth,
      lead_growth: lead_growth,
      renewal_growth: renewal_growth,
      payout_growth: payout_growth,
      sum_insured_growth: sum_insured_growth,
      conversion_rate: conversion_rate,
      avg_policy_value: avg_policy_value,
      customer_retention: customer_retention,
      monthly_recurring_revenue: monthly_recurring_revenue,
      commissions_due: commissions_due
    }
  end

  private

  # DR-wise SQL fragment: only admin-added policies (source of truth matches list pages).
  def dr_filter(_table = nil)
    "AND is_admin_added = true AND is_customer_added = false AND is_agent_added = false"
  end

  # ActiveRecord scope equivalent of dr_filter.
  def dr_scope(model)
    model.where(is_admin_added: true, is_customer_added: false, is_agent_added: false)
  rescue
    model.all
  end

  def build_period_monthly_trend(start_date, end_date)
    trend_data = []
    current_month = start_date.beginning_of_month

    while current_month <= end_date
      period_start = [current_month, start_date].max
      period_end   = [current_month.end_of_month, end_date].min
      trend_data << {
        month:  current_month.strftime('%b %Y'),
        amount: get_premium_for_period(period_start, period_end)
      }
      current_month = current_month.next_month
    end

    trend_data
  rescue => e
    Rails.logger.error "Error building period monthly trend: #{e.message}"
    []
  end

  def get_policies_count_for_period(start_date, end_date)
    health = dr_scope(HealthInsurance).where(policy_start_date: start_date..end_date).count
    life   = dr_scope(LifeInsurance).where(policy_start_date: start_date..end_date).count
    motor  = (dr_scope(MotorInsurance).where(policy_start_date: start_date..end_date).count rescue 0)
    other  = (dr_scope(OtherInsurance).where(policy_start_date: start_date..end_date).count rescue 0)
    health + life + motor + other
  end

  def calculate_total_profit_for_period(start_date, end_date)
    date_range = start_date..end_date
    total = 0.0

    [[HealthInsurance, 'Health'], [LifeInsurance, 'Life'], [MotorInsurance, 'Motor']].each do |klass, label|
      begin
        klass.where(product_through_dr: true)
             .where(policy_booking_date: date_range)
             .each do |p|
          net      = p.net_premium.to_f
          main_pct = p.try(:main_agent_commission_percentage).to_f
          main_amt = p.try(:main_agent_commission_amount).to_f
          main_amt = (net * main_pct / 100.0).round(2) if main_amt.zero? && main_pct > 0 && net > 0
          aff_pct  = p.try(:sub_agent_commission_percentage).to_f
          aff_amt  = p.try(:sub_agent_commission_amount).to_f
          aff_amt  = (net * aff_pct / 100.0).round(2) if aff_amt.zero? && aff_pct > 0 && net > 0
          amb_pct  = p.try(:ambassador_commission_percentage).to_f
          amb_amt  = p.try(:ambassador_commission_amount).to_f
          amb_amt  = (net * amb_pct / 100.0).round(2) if amb_amt.zero? && amb_pct > 0 && net > 0
          inv_pct  = p.try(:investor_commission_percentage).to_f
          inv_amt  = p.try(:investor_commission_amount).to_f
          inv_amt  = (net * inv_pct / 100.0).round(2) if inv_amt.zero? && inv_pct > 0 && net > 0
          co_pct   = p.try(:company_expenses_percentage).to_f
          co_amt   = (net > 0 && co_pct > 0) ? (net * co_pct / 100.0).round(2) : 0.0
          total   += (main_amt - aff_amt - amb_amt - inv_amt - co_amt)
        end
      rescue => e
        Rails.logger.error "Profit calc error (#{label}): #{e.message}"
      end
    end

    total.round(2)
  rescue => e
    Rails.logger.error "calculate_total_profit_for_period failed: #{e.message}"
    0.0
  end

  def get_premium_for_period(start_date, end_date)
    range  = start_date..end_date
    health = (dr_scope(HealthInsurance).where(policy_start_date: range).sum(:net_premium) || 0).to_f
    life   = (dr_scope(LifeInsurance).where(policy_start_date: range).sum(:net_premium) || 0).to_f
    motor  = (dr_scope(MotorInsurance).where(policy_start_date: range).sum(:net_premium).to_f rescue 0.0)
    other  = (dr_scope(OtherInsurance).where(policy_start_date: range).sum(:net_premium).to_f rescue 0.0)
    health + life + motor + other
  end

  def get_renewals_count_for_period(start_date, end_date)
    forty_five_days_ahead = end_date + 45.days
    health = dr_scope(HealthInsurance).where(policy_start_date: start_date..end_date)
                           .where('policy_end_date BETWEEN ? AND ?', end_date, forty_five_days_ahead).count
    life   = dr_scope(LifeInsurance).where(policy_start_date: start_date..end_date)
                        .where('policy_end_date BETWEEN ? AND ?', end_date, forty_five_days_ahead).count
    motor  = (dr_scope(MotorInsurance).where(policy_start_date: start_date..end_date)
                          .where('policy_end_date BETWEEN ? AND ?', end_date, forty_five_days_ahead).count rescue 0)
    health + life + motor
  end

  def get_payouts_for_period(start_date, end_date)
    commission = CommissionPayout.where(created_at: start_date..end_date, status: 'pending').sum(:payout_amount) || 0
    distributor = (DistributorPayout.where(created_at: start_date..end_date, status: 'pending').sum(:payout_amount) rescue 0)
    commission + distributor
  end

  def get_sum_insured_for_period(start_date, end_date)
    health = dr_scope(HealthInsurance).where(policy_start_date: start_date..end_date).sum(:sum_insured) || 0
    life   = dr_scope(LifeInsurance).where(policy_start_date: start_date..end_date).sum(:sum_insured) || 0
    motor  = (dr_scope(MotorInsurance).where(policy_start_date: start_date..end_date).sum(:sum_insured) rescue 0)
    health + life + motor
  end

  def calculate_percentage_change(current_value, previous_value)
    return 0 if previous_value == 0
    return 100 if previous_value == 0 && current_value > 0
    ((current_value.to_f - previous_value.to_f) / previous_value.to_f * 100).round(1)
  end

  def calculate_customer_retention_rate
    # Calculate retention rate for customers who joined 2+ months ago
    two_months_ago = 2.months.ago.beginning_of_month
    old_customers = Customer.where('created_at < ?', two_months_ago).count
    active_old_customers = Customer.where('created_at < ?', two_months_ago).where(status: true).count

    old_customers > 0 ? ((active_old_customers.to_f / old_customers.to_f) * 100).round(1) : 0
  end

  def get_renewal_status_counts
    current_month_start = Date.current.beginning_of_month
    renewed_count = 0

    begin
      renewed_count += dr_scope(HealthInsurance).where('created_at >= ?', current_month_start)
                                               .where(policy_type: 'Renewal').count
      renewed_count += dr_scope(LifeInsurance).where('created_at >= ?', current_month_start)
                                             .where(policy_type: 'Renewal').count
      renewed_count += (dr_scope(MotorInsurance).where('created_at >= ?', current_month_start)
                                               .where(policy_type: 'Renewal').count rescue 0)
    rescue => e
      Rails.logger.error "Error calculating renewal status: #{e.message}"
      renewed_count = 0
    end

    {
      'Renewed' => renewed_count,
      'Pending' => get_renewal_due_count(Date.current + 45.days),
      'Expired' => get_expired_policies_count
    }
  end

  def get_recent_policies
    dr = dr_filter
    sql = "
      SELECT * FROM (
        SELECT
          'Health Insurance' as policy_type,
          h.policy_number,
          h.net_premium as total_premium,
          h.created_at,
          CONCAT(COALESCE(c.first_name, ''), ' ', COALESCE(c.last_name, '')) as customer_name
        FROM health_insurances h
        LEFT JOIN customers c ON h.customer_id = c.id
        WHERE TRUE #{dr}
        ORDER BY h.created_at DESC
        LIMIT 5
      ) AS health
      UNION ALL
      SELECT * FROM (
        SELECT
          'Life Insurance' as policy_type,
          l.policy_number,
          l.net_premium as total_premium,
          l.created_at,
          CONCAT(COALESCE(c.first_name, ''), ' ', COALESCE(c.last_name, '')) as customer_name
        FROM life_insurances l
        LEFT JOIN customers c ON l.customer_id = c.id
        WHERE TRUE #{dr}
        ORDER BY l.created_at DESC
        LIMIT 5
      ) AS life
    "

    begin
      if ActiveRecord::Base.connection.table_exists?('motor_insurances')
        sql += "
          UNION ALL
          SELECT * FROM (
            SELECT
              'Motor Insurance' as policy_type,
              m.policy_number,
              m.net_premium as total_premium,
              m.created_at,
              CONCAT(COALESCE(c.first_name, ''), ' ', COALESCE(c.last_name, '')) as customer_name
            FROM motor_insurances m
            LEFT JOIN customers c ON m.customer_id = c.id
            WHERE TRUE #{dr}
            ORDER BY m.created_at DESC
            LIMIT 5
          ) AS motor
        "
      end
    rescue
    end

    sql += " ORDER BY created_at DESC LIMIT 10"

    results = ActiveRecord::Base.connection.execute(sql)
    results.map do |row|
      {
        type: row['policy_type'],
        customer: row['customer_name'] || 'Unknown',
        policy_number: row['policy_number'],
        premium: row['total_premium'].to_f,
        date: row['created_at']
      }
    end
  rescue => e
    Rails.logger.error "Error fetching recent policies: #{e.message}"
    []
  end

  def get_recent_leads
    # Use select to only fetch needed columns, reducing memory usage
    Lead.select(:id, :lead_id, :name, :current_stage, :created_at)
        .order(created_at: :desc)
        .limit(10)
  rescue => e
    Rails.logger.error "Error fetching recent leads: #{e.message}"
    []
  end

  def calculate_active_affiliates_with_policies
    # Count affiliates who have at least one policy using a single optimized query
    sql = "
      SELECT COUNT(DISTINCT sub_agent_id) as count FROM (
        SELECT sub_agent_id FROM health_insurances WHERE sub_agent_id IS NOT NULL
        UNION
        SELECT sub_agent_id FROM life_insurances WHERE sub_agent_id IS NOT NULL
      ) as affiliate_policies
    "

    # Add motor insurance if table exists
    begin
      if ActiveRecord::Base.connection.table_exists?('motor_insurances')
        sql = "
          SELECT COUNT(DISTINCT sub_agent_id) as count FROM (
            SELECT sub_agent_id FROM health_insurances WHERE sub_agent_id IS NOT NULL
            UNION
            SELECT sub_agent_id FROM life_insurances WHERE sub_agent_id IS NOT NULL
            UNION
            SELECT sub_agent_id FROM motor_insurances WHERE sub_agent_id IS NOT NULL
          ) as affiliate_policies
        "
      end
    rescue
    end

    result = ActiveRecord::Base.connection.execute(sql)
    result.first['count'].to_i
  rescue => e
    Rails.logger.error "Error calculating active affiliates: #{e.message}"
    0
  end

  def get_recently_expired_count
    current_date = Date.current
    forty_five_days_ago = current_date - 45.days
    dr = dr_filter

    sql = "
      SELECT COUNT(*) as count FROM (
        SELECT id FROM health_insurances WHERE TRUE #{dr} AND policy_end_date >= '#{forty_five_days_ago}' AND policy_end_date < '#{current_date}'
          AND (is_renewed IS NULL OR is_renewed = false)
          AND id NOT IN (SELECT original_policy_id FROM health_insurances WHERE original_policy_id IS NOT NULL)
        UNION ALL
        SELECT id FROM life_insurances WHERE TRUE #{dr} AND policy_end_date >= '#{forty_five_days_ago}' AND policy_end_date < '#{current_date}'
          AND (is_renewed IS NULL OR is_renewed = false)
          AND id NOT IN (SELECT original_policy_id FROM life_insurances WHERE original_policy_id IS NOT NULL)
      ) as recently_expired
    "

    result = ActiveRecord::Base.connection.execute(sql)
    count = result.first['count'].to_i

    begin
      if ActiveRecord::Base.connection.table_exists?('motor_insurances')
        count += dr_scope(MotorInsurance).where(policy_end_date: forty_five_days_ago...current_date)
                  .where("NOT EXISTS (
                    SELECT 1 FROM motor_insurances m2
                    WHERE m2.customer_id = motor_insurances.customer_id
                    AND m2.registration_number = motor_insurances.registration_number
                    AND m2.policy_type = 'Renewal'
                    AND m2.policy_start_date > motor_insurances.policy_end_date
                  )").count
      end
    rescue
    end

    begin
      if ActiveRecord::Base.connection.table_exists?('other_insurances')
        count += dr_scope(OtherInsurance).where(policy_end_date: forty_five_days_ago...current_date)
                  .where(is_renewed: [nil, false])
                  .where("id NOT IN (SELECT original_policy_id FROM other_insurances WHERE original_policy_id IS NOT NULL)")
                  .count
      end
    rescue
    end

    count
  rescue => e
    Rails.logger.error "Error getting recently expired count: #{e.message}"
    0
  end

  def get_expired_this_month_count
    current_date = Date.current
    month_start = current_date.beginning_of_month
    dr = dr_filter

    sql = "
      SELECT COUNT(*) as count FROM (
        SELECT id FROM health_insurances WHERE TRUE #{dr} AND policy_end_date BETWEEN '#{month_start}' AND '#{current_date}' AND policy_end_date < '#{current_date}'
          AND (is_renewed IS NULL OR is_renewed = false)
          AND id NOT IN (SELECT original_policy_id FROM health_insurances WHERE original_policy_id IS NOT NULL)
        UNION ALL
        SELECT id FROM life_insurances WHERE TRUE #{dr} AND policy_end_date BETWEEN '#{month_start}' AND '#{current_date}' AND policy_end_date < '#{current_date}'
          AND (is_renewed IS NULL OR is_renewed = false)
          AND id NOT IN (SELECT original_policy_id FROM life_insurances WHERE original_policy_id IS NOT NULL)
      ) as expired_this_month
    "

    result = ActiveRecord::Base.connection.execute(sql)
    count = result.first['count'].to_i

    begin
      if ActiveRecord::Base.connection.table_exists?('motor_insurances')
        count += dr_scope(MotorInsurance).where(policy_end_date: month_start...current_date)
                  .where("NOT EXISTS (
                    SELECT 1 FROM motor_insurances m2
                    WHERE m2.customer_id = motor_insurances.customer_id
                    AND m2.registration_number = motor_insurances.registration_number
                    AND m2.policy_type = 'Renewal'
                    AND m2.policy_start_date > motor_insurances.policy_end_date
                  )").count
      end
    rescue
    end

    count
  rescue => e
    Rails.logger.error "Error getting expired this month count: #{e.message}"
    0
  end

  def get_renewal_opportunities_count
    current_date = Date.current
    sixty_days_from_now = current_date + 60.days
    dr = dr_filter

    sql = "
      SELECT COUNT(*) as count FROM (
        SELECT id FROM health_insurances WHERE TRUE #{dr} AND policy_end_date BETWEEN '#{current_date}' AND '#{sixty_days_from_now}' AND policy_type != 'Renewal'
        UNION ALL
        SELECT id FROM life_insurances WHERE TRUE #{dr} AND policy_end_date BETWEEN '#{current_date}' AND '#{sixty_days_from_now}' AND policy_type != 'Renewal'
      ) as opportunities
    "

    result = ActiveRecord::Base.connection.execute(sql)
    count = result.first['count'].to_i

    begin
      if ActiveRecord::Base.connection.table_exists?('motor_insurances')
        count += dr_scope(MotorInsurance).where(policy_end_date: current_date..sixty_days_from_now).where.not(policy_type: 'Renewal').count
      end
    rescue
    end

    count
  rescue => e
    Rails.logger.error "Error getting renewal opportunities count: #{e.message}"
    0
  end

  def fetch_card_detail_records(metric, start_date, end_date)
    next_day = end_date + 1.day
    range    = start_date..end_date

    case metric
    when 'customers'
      Customer.where("created_at >= ? AND created_at < ?", start_date, next_day)
              .order(created_at: :desc).map do |c|
        { type: 'Customer', name: c.display_name, created_at: c.created_at.strftime('%d-%m-%Y'),
          city: c.city.to_s, mobile: c.mobile.to_s,
          customer_link: "/admin/customers/#{c.id}" }
      end
    when 'policies', 'premium'
      collect_policies_for_detail(range)
    when 'leads'
      active_stages = ['lead_generated', 'consultation_scheduled', 'one_on_one', 'follow_up',
                       'follow_up_successful', 'follow_up_unsuccessful', 're_follow_up']
      Lead.where("created_at >= ? AND created_at < ?", start_date, next_day)
          .where(current_stage: active_stages)
          .order(created_at: :desc).map do |l|
        { type: 'Lead', name: l.name.to_s, stage: l.current_stage.to_s.humanize,
          created_at: l.created_at.strftime('%d-%m-%Y') }
      end
    when 'investors'
      Investor.order(created_at: :desc).map do |i|
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
    Rails.logger.error "card_detail fetch error: #{e.message}"
    []
  end

  def collect_policies_for_detail(range)
    policies = []
    dr_scope(HealthInsurance).where(policy_start_date: range).includes(:customer).order(policy_start_date: :desc).each do |p|
      policies << format_policy_detail(p, 'Health', 'health')
    end
    dr_scope(LifeInsurance).where(policy_start_date: range).includes(:customer).order(policy_start_date: :desc).each do |p|
      policies << format_policy_detail(p, 'Life', 'life')
    end
    begin
      dr_scope(MotorInsurance).where(policy_start_date: range).includes(:customer).order(policy_start_date: :desc).each do |p|
        policies << format_policy_detail(p, 'Motor', 'motor')
      end
    rescue; end
    begin
      dr_scope(OtherInsurance).where(policy_start_date: range).includes(:customer).order(policy_start_date: :desc).each do |p|
        policies << format_policy_detail(p, 'Other', 'other')
      end
    rescue; end
    policies.sort_by { |p| p[:policy_start_date_raw] || '' }.reverse
  end

  def format_policy_detail(p, type, route_key)
    { type: type,
      policy_number: p.policy_number.to_s,
      policy_link: "/admin/insurance/#{route_key}/#{p.id}",
      drwise: p.is_admin_added == true && p.is_customer_added == false && p.is_agent_added == false,
      customer: p.customer&.display_name || 'Unknown',
      policy_start_date: p.policy_start_date&.strftime('%d-%m-%Y'),
      policy_start_date_raw: p.policy_start_date.to_s,
      policy_end_date: p.policy_end_date&.strftime('%d-%m-%Y'),
      created_at: p.created_at.strftime('%d-%m-%Y'),
      net_premium: p.net_premium.to_f.round(2),
      total_premium: p.total_premium.to_f.round(2) }
  end

end
