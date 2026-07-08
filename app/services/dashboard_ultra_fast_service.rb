class DashboardUltraFastService
  CACHE_VERSION = 'v4'
  CACHE_TTL = 30.minutes
  REAL_TIME_TTL = 30.seconds

  class << self
    def fetch_stats
      # Try to get from memory cache first (fastest)
      return memory_cache if memory_cache_valid?

      # Then try Redis cache (very fast)
      stats = fetch_from_cache
      return stats if stats.present?

      # Finally compute if needed (slower, but happens rarely)
      compute_and_cache_stats
    end

    def preload_cache!
      # Run this in background job every 5 minutes
      stats = compute_all_stats_optimized
      cache_stats(stats)
      stats
    end

    def instant_stats
      # Returns pre-computed stats instantly from cache
      # Falls back to last known good stats if current computation is running
      Rails.cache.fetch("dashboard_instant_#{cache_key}", expires_in: 1.hour) do
        fetch_stats
      end
    end

    private

    def memory_cache
      Thread.current[:dashboard_cache]
    end

    def memory_cache_valid?
      Thread.current[:dashboard_cache].present? &&
      Thread.current[:dashboard_cache_expires_at].present? &&
      Thread.current[:dashboard_cache_expires_at] > Time.current
    end

    def set_memory_cache(stats)
      Thread.current[:dashboard_cache] = stats
      Thread.current[:dashboard_cache_expires_at] = 10.seconds.from_now
      stats
    end

    def cache_key
      "dashboard_ultra_#{CACHE_VERSION}_#{Date.current}"
    end

    def fetch_from_cache
      stats = Rails.cache.read(cache_key)
      set_memory_cache(stats) if stats.present?
      stats
    end

    def cache_stats(stats)
      Rails.cache.write(cache_key, stats, expires_in: CACHE_TTL)
      Rails.cache.write("#{cache_key}_backup", stats, expires_in: 24.hours)
      set_memory_cache(stats)
      stats
    end

    def compute_and_cache_stats
      # Try to use backup cache while computing
      backup = Rails.cache.read("#{cache_key}_backup")
      return backup if backup.present? && computing_in_progress?

      # Mark as computing
      Rails.cache.write("#{cache_key}_computing", true, expires_in: 30.seconds)

      stats = compute_all_stats_optimized
      cache_stats(stats)

      # Clear computing flag
      Rails.cache.delete("#{cache_key}_computing")

      stats
    rescue => e
      Rails.logger.error "Dashboard stats computation failed: #{e.message}"
      Rails.cache.delete("#{cache_key}_computing")
      Rails.cache.read("#{cache_key}_backup") || {}
    end

    def computing_in_progress?
      Rails.cache.read("#{cache_key}_computing").present?
    end

    def compute_all_stats_optimized
      # Use raw SQL for maximum performance
      stats = {}

      # Single massive optimized query for all counts and sums
      main_stats_sql = <<-SQL
        WITH RECURSIVE date_series AS (
          SELECT DATE '#{Date.current}' as current_date,
                 DATE '#{Date.current + 45.days}' as future_date,
                 DATE '#{Date.current.beginning_of_month}' as month_start,
                 DATE '#{1.month.ago.beginning_of_month}' as last_month_start,
                 DATE '#{1.month.ago.end_of_month}' as last_month_end
        ),
        customer_stats AS (
          SELECT
            COUNT(*) as total,
            COUNT(CASE WHEN status = true THEN 1 END) as active,
            COUNT(CASE WHEN created_at >= (SELECT month_start FROM date_series) THEN 1 END) as current_month,
            COUNT(CASE WHEN created_at BETWEEN (SELECT last_month_start FROM date_series) AND (SELECT last_month_end FROM date_series) THEN 1 END) as last_month
          FROM customers
        ),
        lead_stats AS (
          SELECT
            COUNT(*) as total,
            COUNT(CASE WHEN current_stage = 'converted' THEN 1 END) as converted,
            COUNT(CASE WHEN current_stage IN ('lead_generated', 'follow_up', 'follow_up_successful', 'consultation_scheduled', 'one_on_one') THEN 1 END) as pending,
            COUNT(CASE WHEN created_at >= (SELECT month_start FROM date_series) THEN 1 END) as current_month,
            COUNT(CASE WHEN created_at BETWEEN (SELECT last_month_start FROM date_series) AND (SELECT last_month_end FROM date_series) THEN 1 END) as last_month
          FROM leads
        ),
        affiliate_stats AS (
          SELECT
            COUNT(*) as total,
            COUNT(CASE WHEN status = 0 THEN 1 END) as active,
            COUNT(CASE WHEN created_at >= (SELECT month_start FROM date_series) THEN 1 END) as current_month,
            COUNT(CASE WHEN created_at BETWEEN (SELECT last_month_start FROM date_series) AND (SELECT last_month_end FROM date_series) THEN 1 END) as last_month
          FROM sub_agents
        ),
        distributor_stats AS (
          SELECT
            COUNT(*) as total,
            COUNT(CASE WHEN created_at >= (SELECT month_start FROM date_series) THEN 1 END) as current_month,
            COUNT(CASE WHEN created_at BETWEEN (SELECT last_month_start FROM date_series) AND (SELECT last_month_end FROM date_series) THEN 1 END) as last_month
          FROM distributors
        ),
        health_stats AS (
          SELECT
            COUNT(*) as count,
            COALESCE(SUM(net_premium), 0) as premium,
            COALESCE(SUM(sum_insured), 0) as sum_insured,
            COUNT(CASE WHEN policy_end_date >= (SELECT current_date FROM date_series) THEN 1 END) as active,
            COUNT(CASE WHEN policy_end_date < (SELECT current_date FROM date_series) THEN 1 END) as expired,
            COUNT(CASE WHEN policy_end_date BETWEEN (SELECT current_date FROM date_series) AND (SELECT future_date FROM date_series) THEN 1 END) as expiring,
            COUNT(CASE WHEN policy_type = 'Renewal' AND created_at >= (SELECT month_start FROM date_series) THEN 1 END) as renewed_this_month,
            COALESCE(SUM(CASE WHEN created_at >= (SELECT month_start FROM date_series) THEN net_premium END), 0) as current_month_premium,
            COALESCE(SUM(CASE WHEN created_at BETWEEN (SELECT last_month_start FROM date_series) AND (SELECT last_month_end FROM date_series) THEN net_premium END), 0) as last_month_premium
          FROM health_insurances
        ),
        life_stats AS (
          SELECT
            COUNT(*) as count,
            COALESCE(SUM(net_premium), 0) as premium,
            COALESCE(SUM(sum_insured), 0) as sum_insured,
            COUNT(CASE WHEN policy_end_date >= (SELECT current_date FROM date_series) THEN 1 END) as active,
            COUNT(CASE WHEN policy_end_date < (SELECT current_date FROM date_series) THEN 1 END) as expired,
            COUNT(CASE WHEN policy_end_date BETWEEN (SELECT current_date FROM date_series) AND (SELECT future_date FROM date_series) THEN 1 END) as expiring,
            COUNT(CASE WHEN policy_type = 'Renewal' AND created_at >= (SELECT month_start FROM date_series) THEN 1 END) as renewed_this_month,
            COALESCE(SUM(CASE WHEN created_at >= (SELECT month_start FROM date_series) THEN net_premium END), 0) as current_month_premium,
            COALESCE(SUM(CASE WHEN created_at BETWEEN (SELECT last_month_start FROM date_series) AND (SELECT last_month_end FROM date_series) THEN net_premium END), 0) as last_month_premium
          FROM life_insurances
        ),
        commission_stats AS (
          SELECT
            COALESCE(SUM(CASE WHEN status = 'pending' THEN payout_amount END), 0) as pending,
            COALESCE(SUM(CASE WHEN status = 'paid' THEN payout_amount END), 0) as paid,
            COALESCE(SUM(payout_amount), 0) as total
          FROM commission_payouts
        )
        SELECT
          -- Customer stats
          c.total as total_customers,
          c.active as active_customers,
          c.total - c.active as inactive_customers,
          c.current_month as customers_current_month,
          c.last_month as customers_last_month,

          -- Lead stats
          l.total as total_leads,
          l.converted as converted_leads,
          l.pending as pending_leads,
          CASE WHEN l.total > 0 THEN ROUND((l.converted::numeric / l.total) * 100, 2) ELSE 0 END as lead_conversion_percentage,
          l.current_month as leads_current_month,
          l.last_month as leads_last_month,

          -- Affiliate stats
          a.total as total_affiliates,
          a.active as total_sub_agents,
          a.current_month as affiliates_current_month,
          a.last_month as affiliates_last_month,

          -- Distributor stats
          d.total as total_ambassadors,
          d.current_month as ambassadors_current_month,
          d.last_month as ambassadors_last_month,

          -- Insurance stats
          h.count as health_count,
          ls.count as life_count,
          h.count + ls.count as base_total_policies,
          h.premium + ls.premium as base_total_premium,
          h.sum_insured + ls.sum_insured as base_total_sum_insured,
          h.active + ls.active as active_policies,
          h.expired + ls.expired as expired_policies_count,
          h.expiring + ls.expiring as renewal_due_count,
          h.renewed_this_month + ls.renewed_this_month as renewed_this_month,
          h.current_month_premium + ls.current_month_premium as current_month_premium,
          h.last_month_premium + ls.last_month_premium as last_month_premium,

          -- Commission stats
          cs.pending as pending_payouts,
          cs.paid as paid_payouts,
          cs.total as total_payouts

        FROM customer_stats c
        CROSS JOIN lead_stats l
        CROSS JOIN affiliate_stats a
        CROSS JOIN distributor_stats d
        CROSS JOIN health_stats h
        CROSS JOIN life_stats ls
        CROSS JOIN commission_stats cs
      SQL

      result = ActiveRecord::Base.connection.select_one(main_stats_sql)

      # Convert to proper types and add to stats
      result.each do |key, value|
        stats[key.to_sym] = value.is_a?(String) ? value.to_f : value
      end

      # Handle motor and other insurance if they exist
      add_optional_insurance_stats!(stats)

      # Calculate growth percentages
      calculate_growth_metrics!(stats)

      # Add recent items (cached separately for shorter TTL)
      stats[:recent_policies] = fetch_recent_policies_cached
      stats[:recent_leads] = fetch_recent_leads_cached

      # Add calculated fields
      stats[:total_policies] = stats[:base_total_policies] + (stats[:motor_count] || 0) + (stats[:other_count] || 0)
      stats[:total_premium_collected] = stats[:base_total_premium] + (stats[:motor_premium] || 0) + (stats[:other_premium] || 0)
      stats[:total_sum_insured] = stats[:base_total_sum_insured] + (stats[:motor_sum_insured] || 0) + (stats[:other_sum_insured] || 0)

      # Add renewal status
      stats[:renewal_status] = {
        'Renewed' => stats[:renewed_this_month] || 0,
        'Pending' => stats[:renewal_due_count] || 0,
        'Expired' => stats[:expired_policies_count] || 0
      }

      # Performance metrics
      stats[:avg_policy_value] = stats[:total_policies] > 0 ? (stats[:total_premium_collected] / stats[:total_policies]).round(0) : 0
      stats[:monthly_recurring_revenue] = (stats[:total_premium_collected] / 12.0).round(0)
      stats[:commissions_due] = stats[:pending_payouts] || 0

      stats
    end

    def add_optional_insurance_stats!(stats)
      # Check for motor insurance
      if ActiveRecord::Base.connection.table_exists?('motor_insurances')
        motor_sql = <<-SQL
          SELECT
            COUNT(*) as count,
            COALESCE(SUM(net_premium), 0) as premium,
            COALESCE(SUM(sum_insured), 0) as sum_insured,
            COUNT(CASE WHEN policy_end_date < CURRENT_DATE THEN 1 END) as expired,
            COUNT(CASE WHEN policy_end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '45 days' THEN 1 END) as expiring
          FROM motor_insurances
        SQL

        motor_result = ActiveRecord::Base.connection.select_one(motor_sql)
        stats[:motor_count] = motor_result['count'].to_i
        stats[:motor_premium] = motor_result['premium'].to_f
        stats[:motor_sum_insured] = motor_result['sum_insured'].to_f
        stats[:expired_policies_count] += motor_result['expired'].to_i
        stats[:renewal_due_count] += motor_result['expiring'].to_i
      else
        stats[:motor_count] = 0
        stats[:motor_premium] = 0
        stats[:motor_sum_insured] = 0
      end

      # Check for other insurance
      if ActiveRecord::Base.connection.table_exists?('other_insurances')
        other_sql = <<-SQL
          SELECT
            COUNT(*) as count,
            COALESCE(SUM(net_premium), 0) as premium,
            COALESCE(SUM(sum_insured), 0) as sum_insured,
            COUNT(CASE WHEN policy_end_date < CURRENT_DATE THEN 1 END) as expired,
            COUNT(CASE WHEN policy_end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '45 days' THEN 1 END) as expiring
          FROM other_insurances
        SQL

        other_result = ActiveRecord::Base.connection.select_one(other_sql)
        stats[:other_count] = other_result['count'].to_i
        stats[:other_premium] = other_result['premium'].to_f
        stats[:other_sum_insured] = other_result['sum_insured'].to_f
        stats[:expired_policies_count] += other_result['expired'].to_i
        stats[:renewal_due_count] += other_result['expiring'].to_i
      else
        stats[:other_count] = 0
        stats[:other_premium] = 0
        stats[:other_sum_insured] = 0
      end
    end

    def calculate_growth_metrics!(stats)
      stats[:customer_growth] = calculate_percentage(stats[:customers_current_month], stats[:customers_last_month])
      stats[:lead_growth] = calculate_percentage(stats[:leads_current_month], stats[:leads_last_month])
      stats[:affiliate_growth] = calculate_percentage(stats[:affiliates_current_month], stats[:affiliates_last_month])
      stats[:ambassador_growth] = calculate_percentage(stats[:ambassadors_current_month], stats[:ambassadors_last_month])
      stats[:policy_growth] = calculate_percentage(stats[:current_month_premium], stats[:last_month_premium])
      stats[:premium_growth] = stats[:policy_growth]

      # Calculate retention rate
      two_months_ago = 2.months.ago.beginning_of_month
      old_customers_sql = "SELECT COUNT(*) as total, COUNT(CASE WHEN status = true THEN 1 END) as active FROM customers WHERE created_at < '#{two_months_ago}'"
      retention_result = ActiveRecord::Base.connection.select_one(old_customers_sql)

      stats[:customer_retention] = retention_result['total'].to_i > 0 ?
        ((retention_result['active'].to_f / retention_result['total'].to_f) * 100).round(1) : 0
    end

    def calculate_percentage(current, previous)
      return 0 if previous.nil? || previous == 0
      return 100 if previous == 0 && current > 0
      ((current.to_f - previous.to_f) / previous.to_f * 100).round(1)
    end

    def fetch_recent_policies_cached
      Rails.cache.fetch("dashboard_recent_policies_#{Date.current}", expires_in: REAL_TIME_TTL) do
        sql = <<-SQL
          SELECT * FROM (
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
          ) AS health
          UNION ALL
          SELECT * FROM (
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
          ) AS life
          ORDER BY created_at DESC
          LIMIT 10
        SQL

        ActiveRecord::Base.connection.select_all(sql).map do |row|
          {
            type: row['policy_type'],
            customer: row['customer_name'] || 'Unknown',
            policy_number: row['policy_number'],
            premium: row['total_premium'].to_f,
            date: row['created_at']
          }
        end
      end
    end

    def fetch_recent_leads_cached
      Rails.cache.fetch("dashboard_recent_leads_#{Date.current}", expires_in: REAL_TIME_TTL) do
        Lead.select(:id, :lead_id, :name, :current_stage, :created_at)
            .order(created_at: :desc)
            .limit(10)
            .to_a
      end
    end
  end
end