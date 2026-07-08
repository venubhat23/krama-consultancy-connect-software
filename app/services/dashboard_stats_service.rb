class DashboardStatsService
  include ActiveSupport::NumberHelper

  def self.fetch_stats
    new.fetch_stats
  end

  def fetch_stats
    Rails.cache.fetch(cache_key, expires_in: 5.minutes, race_condition_ttl: 10.seconds) do
      collect_all_stats
    end
  end

  def refresh_cache!
    Rails.cache.delete(cache_key)
    fetch_stats
  end

  private

  def cache_key
    "dashboard_stats_v3_#{Date.current}"
  end

  def collect_all_stats
    stats = {}

    # Use parallel processing with connection pooling
    threads = []

    # Customer stats
    threads << Thread.new do
      stats[:customer_stats] = fetch_customer_stats
    end

    # Lead stats
    threads << Thread.new do
      stats[:lead_stats] = fetch_lead_stats
    end

    # Insurance stats (combined query)
    threads << Thread.new do
      stats[:insurance_stats] = fetch_insurance_stats
    end

    # Payout stats
    threads << Thread.new do
      stats[:payout_stats] = fetch_payout_stats
    end

    # Growth metrics
    threads << Thread.new do
      stats[:growth_metrics] = fetch_growth_metrics
    end

    # Recent items
    threads << Thread.new do
      stats[:recent_items] = fetch_recent_items
    end

    # Wait for all threads to complete
    threads.each(&:join)

    # Flatten the stats for easy access
    flatten_stats(stats)
  end

  def fetch_customer_stats
    result = ActiveRecord::Base.connection.select_one(
      "SELECT
        COUNT(*) as total,
        COUNT(CASE WHEN status = true THEN 1 END) as active
      FROM customers"
    )

    {
      total_customers: result['total'].to_i,
      active_customers: result['active'].to_i,
      inactive_customers: result['total'].to_i - result['active'].to_i
    }
  end

  def fetch_lead_stats
    result = ActiveRecord::Base.connection.select_one(
      "SELECT
        COUNT(*) as total,
        COUNT(CASE WHEN current_stage = 'converted' THEN 1 END) as converted,
        COUNT(CASE WHEN current_stage IN ('lead_generated', 'follow_up', 'follow_up_successful', 'consultation_scheduled', 'one_on_one') THEN 1 END) as pending
      FROM leads"
    )

    total = result['total'].to_i
    converted = result['converted'].to_i

    {
      total_leads: total,
      converted_leads: converted,
      pending_leads: result['pending'].to_i,
      lead_conversion_percentage: total > 0 ? ((converted.to_f / total) * 100).round(2) : 0
    }
  end

  def fetch_insurance_stats
    # Single optimized query to get all insurance stats
    sql = "
      WITH insurance_data AS (
        SELECT
          'health' as type,
          COUNT(*) as count,
          COALESCE(SUM(net_premium), 0) as total_premium,
          COALESCE(SUM(sum_insured), 0) as total_sum_insured,
          COUNT(CASE WHEN policy_end_date >= CURRENT_DATE THEN 1 END) as active_count,
          COUNT(CASE WHEN policy_end_date < CURRENT_DATE THEN 1 END) as expired_count,
          COUNT(CASE WHEN policy_end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '45 days' THEN 1 END) as expiring_soon
        FROM health_insurances
        UNION ALL
        SELECT
          'life' as type,
          COUNT(*) as count,
          COALESCE(SUM(net_premium), 0) as total_premium,
          COALESCE(SUM(sum_insured), 0) as total_sum_insured,
          COUNT(CASE WHEN policy_end_date >= CURRENT_DATE THEN 1 END) as active_count,
          COUNT(CASE WHEN policy_end_date < CURRENT_DATE THEN 1 END) as expired_count,
          COUNT(CASE WHEN policy_end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '45 days' THEN 1 END) as expiring_soon
        FROM life_insurances
      )
      SELECT
        SUM(count) as total_policies,
        SUM(total_premium) as total_premium,
        SUM(total_sum_insured) as total_sum_insured,
        SUM(active_count) as active_policies,
        SUM(expired_count) as expired_policies,
        SUM(expiring_soon) as renewal_due_count,
        MAX(CASE WHEN type = 'health' THEN count ELSE 0 END) as health_count,
        MAX(CASE WHEN type = 'life' THEN count ELSE 0 END) as life_count
      FROM insurance_data
    "

    result = ActiveRecord::Base.connection.select_one(sql)

    # Handle optional motor and other insurance tables
    motor_count = 0
    other_count = 0

    begin
      if ActiveRecord::Base.connection.table_exists?('motor_insurances')
        motor_stats = ActiveRecord::Base.connection.select_one(
          "SELECT
            COUNT(*) as count,
            COALESCE(SUM(net_premium), 0) as premium,
            COALESCE(SUM(sum_insured), 0) as sum_insured,
            COUNT(CASE WHEN policy_end_date < CURRENT_DATE THEN 1 END) as expired,
            COUNT(CASE WHEN policy_end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '45 days' THEN 1 END) as expiring
          FROM motor_insurances"
        )
        motor_count = motor_stats['count'].to_i
        result['total_policies'] = result['total_policies'].to_i + motor_count
        result['total_premium'] = result['total_premium'].to_f + motor_stats['premium'].to_f
        result['total_sum_insured'] = result['total_sum_insured'].to_f + motor_stats['sum_insured'].to_f
        result['expired_policies'] = result['expired_policies'].to_i + motor_stats['expired'].to_i
        result['renewal_due_count'] = result['renewal_due_count'].to_i + motor_stats['expiring'].to_i
      end
    rescue
    end

    begin
      if ActiveRecord::Base.connection.table_exists?('other_insurances')
        other_stats = ActiveRecord::Base.connection.select_one(
          "SELECT
            COUNT(*) as count,
            COALESCE(SUM(net_premium), 0) as premium,
            COALESCE(SUM(sum_insured), 0) as sum_insured,
            COUNT(CASE WHEN policy_end_date < CURRENT_DATE THEN 1 END) as expired,
            COUNT(CASE WHEN policy_end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '45 days' THEN 1 END) as expiring
          FROM other_insurances"
        )
        other_count = other_stats['count'].to_i
        result['total_policies'] = result['total_policies'].to_i + other_count
        result['total_premium'] = result['total_premium'].to_f + other_stats['premium'].to_f
        result['total_sum_insured'] = result['total_sum_insured'].to_f + other_stats['sum_insured'].to_f
        result['expired_policies'] = result['expired_policies'].to_i + other_stats['expired'].to_i
        result['renewal_due_count'] = result['renewal_due_count'].to_i + other_stats['expiring'].to_i
      end
    rescue
    end

    {
      total_policies: result['total_policies'].to_i,
      health_count: result['health_count'].to_i,
      life_count: result['life_count'].to_i,
      motor_count: motor_count,
      other_count: other_count,
      total_premium_collected: result['total_premium'].to_f,
      total_sum_insured: result['total_sum_insured'].to_f,
      expired_policies_count: result['expired_policies'].to_i,
      renewal_due_count: result['renewal_due_count'].to_i,
      active_policies_count: result['active_policies'].to_i
    }
  end

  def fetch_payout_stats
    # Optimized single query for payout stats
    commission_stats = CommissionPayout
      .select("
        SUM(CASE WHEN status = 'pending' THEN payout_amount ELSE 0 END) as pending,
        SUM(CASE WHEN status = 'paid' THEN payout_amount ELSE 0 END) as paid,
        SUM(payout_amount) as total
      ")
      .first

    distributor_stats = { 'pending' => 0, 'paid' => 0, 'total' => 0 }

    begin
      if ActiveRecord::Base.connection.table_exists?('distributor_payouts')
        distributor_stats = DistributorPayout
          .select("
            SUM(CASE WHEN status = 'pending' THEN payout_amount ELSE 0 END) as pending,
            SUM(CASE WHEN status = 'paid' THEN payout_amount ELSE 0 END) as paid,
            SUM(payout_amount) as total
          ")
          .first
      end
    rescue
    end

    {
      pending_payouts: (commission_stats&.pending || 0) + (distributor_stats&.pending || 0),
      paid_payouts: (commission_stats&.paid || 0) + (distributor_stats&.paid || 0),
      total_payouts: (commission_stats&.total || 0) + (distributor_stats&.total || 0)
    }
  end

  def fetch_growth_metrics
    current_month_start = Date.current.beginning_of_month
    last_month_start = 1.month.ago.beginning_of_month
    last_month_end = 1.month.ago.end_of_month

    # Use single query to get current and last month stats
    sql = "
      SELECT
        'current' as period,
        (SELECT COUNT(*) FROM customers WHERE created_at >= '#{current_month_start}') as customers,
        (SELECT COUNT(*) FROM leads WHERE created_at >= '#{current_month_start}') as leads,
        (SELECT COUNT(*) FROM sub_agents WHERE created_at >= '#{current_month_start}') as affiliates,
        (SELECT COUNT(*) FROM distributors WHERE created_at >= '#{current_month_start}') as ambassadors
      UNION ALL
      SELECT
        'last' as period,
        (SELECT COUNT(*) FROM customers WHERE created_at BETWEEN '#{last_month_start}' AND '#{last_month_end}') as customers,
        (SELECT COUNT(*) FROM leads WHERE created_at BETWEEN '#{last_month_start}' AND '#{last_month_end}') as leads,
        (SELECT COUNT(*) FROM sub_agents WHERE created_at BETWEEN '#{last_month_start}' AND '#{last_month_end}') as affiliates,
        (SELECT COUNT(*) FROM distributors WHERE created_at BETWEEN '#{last_month_start}' AND '#{last_month_end}') as ambassadors
    "

    results = ActiveRecord::Base.connection.select_all(sql)
    current = results.find { |r| r['period'] == 'current' }
    last = results.find { |r| r['period'] == 'last' }

    {
      customer_growth: calculate_percentage_change(current['customers'], last['customers']),
      lead_growth: calculate_percentage_change(current['leads'], last['leads']),
      affiliate_growth: calculate_percentage_change(current['affiliates'], last['affiliates']),
      ambassador_growth: calculate_percentage_change(current['ambassadors'], last['ambassadors'])
    }
  end

  def fetch_recent_items
    # Optimized single query for recent policies
    sql = "
      (
        SELECT
          'Health Insurance' as policy_type,
          h.policy_number,
          h.net_premium as total_premium,
          h.created_at,
          CASE
            WHEN c.customer_type = 'individual' THEN TRIM(CONCAT(c.first_name, ' ', COALESCE(c.middle_name, ''), ' ', c.last_name))
            ELSE c.company_name
          END as customer_name
        FROM health_insurances h
        LEFT JOIN customers c ON h.customer_id = c.id
        ORDER BY h.created_at DESC
        LIMIT 5
      )
      UNION ALL
      (
        SELECT
          'Life Insurance' as policy_type,
          l.policy_number,
          l.net_premium as total_premium,
          l.created_at,
          CASE
            WHEN c.customer_type = 'individual' THEN TRIM(CONCAT(c.first_name, ' ', COALESCE(c.middle_name, ''), ' ', c.last_name))
            ELSE c.company_name
          END as customer_name
        FROM life_insurances l
        LEFT JOIN customers c ON l.customer_id = c.id
        ORDER BY l.created_at DESC
        LIMIT 5
      )
      ORDER BY created_at DESC
      LIMIT 10
    "

    policies = ActiveRecord::Base.connection.select_all(sql).map do |row|
      {
        type: row['policy_type'],
        customer: row['customer_name'] || 'Unknown',
        policy_number: row['policy_number'],
        premium: row['total_premium'].to_f,
        date: row['created_at']
      }
    end

    # Recent leads with minimal data
    leads = Lead
      .select(:id, :lead_id, :name, :current_stage, :created_at)
      .order(created_at: :desc)
      .limit(10)

    {
      recent_policies: policies,
      recent_leads: leads
    }
  end

  def calculate_percentage_change(current, last)
    current = current.to_f
    last = last.to_f
    return 0 if last == 0
    return 100 if last == 0 && current > 0
    ((current - last) / last * 100).round(1)
  end

  def flatten_stats(stats)
    flattened = {}

    # Flatten all nested hashes
    stats.each do |_key, value|
      if value.is_a?(Hash)
        value.each do |sub_key, sub_value|
          flattened[sub_key] = sub_value
        end
      else
        flattened[_key] = value
      end
    end

    # Add calculated fields
    flattened[:total_affiliates] = SubAgent.count
    flattened[:total_sub_agents] = SubAgent.where(status: 'active').count
    flattened[:total_ambassadors] = Distributor.count

    # Add renewal status
    flattened[:renewal_status] = {
      'Renewed' => count_renewals_this_month,
      'Pending' => flattened[:renewal_due_count] || 0,
      'Expired' => flattened[:expired_policies_count] || 0
    }

    flattened
  end

  def count_renewals_this_month
    current_month_start = Date.current.beginning_of_month
    count = 0

    begin
      count += HealthInsurance.where('created_at >= ?', current_month_start)
                              .where(policy_type: 'Renewal').count
      count += LifeInsurance.where('created_at >= ?', current_month_start)
                            .where(policy_type: 'Renewal').count

      if ActiveRecord::Base.connection.table_exists?('motor_insurances')
        count += MotorInsurance.where('created_at >= ?', current_month_start)
                               .where(policy_type: 'Renewal').count
      end
    rescue
    end

    count
  end
end