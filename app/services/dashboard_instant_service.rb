class DashboardInstantService
  class << self
    def fetch_stats
      # Try materialized view first (FASTEST - sub 10ms response)
      view_stats = fetch_from_materialized_view
      return format_view_stats(view_stats) if view_stats.present? && view_fresh?(view_stats)

      # Fall back to ultra fast service
      DashboardUltraFastService.instant_stats
    end

    def refresh_materialized_view!
      # Refresh the materialized view in background
      ActiveRecord::Base.connection.execute('SELECT refresh_dashboard_stats_view()')
      Rails.logger.info "[DashboardView] Materialized view refreshed at #{Time.current}"
    rescue => e
      Rails.logger.error "[DashboardView] Failed to refresh view: #{e.message}"
    end

    private

    def fetch_from_materialized_view
      ActiveRecord::Base.connection.select_one(
        'SELECT * FROM dashboard_stats_view LIMIT 1'
      )
    rescue => e
      Rails.logger.error "[DashboardView] Error fetching from view: #{e.message}"
      nil
    end

    def view_fresh?(view_stats)
      calculated_at = view_stats['calculated_at']
      return false unless calculated_at.present?

      # Consider fresh if calculated within last 10 minutes
      Time.parse(calculated_at.to_s) > 10.minutes.ago
    end

    def format_view_stats(stats)
      formatted = {}

      # Map database column names to expected keys
      mapping = {
        'total_customers' => :total_customers,
        'active_customers' => :active_customers,
        'customers_this_month' => :customers_current_month,
        'total_leads' => :total_leads,
        'converted_leads' => :converted_leads,
        'pending_leads' => :pending_leads,
        'total_affiliates' => :total_affiliates,
        'active_sub_agents' => :total_sub_agents,
        'total_distributors' => :total_ambassadors,
        'health_insurance_count' => :health_count,
        'life_insurance_count' => :life_count,
        'health_premium_total' => :health_premium,
        'life_premium_total' => :life_premium,
        'health_sum_insured' => :health_sum_insured,
        'life_sum_insured' => :life_sum_insured,
        'health_active' => :health_active_count,
        'life_active' => :life_active_count,
        'health_expired' => :health_expired_count,
        'life_expired' => :life_expired_count,
        'health_expiring' => :health_expiring_count,
        'life_expiring' => :life_expiring_count,
        'commission_pending' => :pending_payouts,
        'commission_paid' => :paid_payouts,
        'commission_total' => :total_payouts
      }

      mapping.each do |db_key, app_key|
        formatted[app_key] = stats[db_key]&.to_f || 0
      end

      # Calculate derived values
      formatted[:inactive_customers] = formatted[:total_customers] - formatted[:active_customers]
      formatted[:total_policies] = formatted[:health_count] + formatted[:life_count]
      formatted[:total_premium_collected] = formatted[:health_premium] + formatted[:life_premium]
      formatted[:total_sum_insured] = formatted[:health_sum_insured] + formatted[:life_sum_insured]
      formatted[:expired_policies_count] = formatted[:health_expired_count] + formatted[:life_expired_count]
      formatted[:renewal_due_count] = formatted[:health_expiring_count] + formatted[:life_expiring_count]

      # Add motor and other counts (these change infrequently, can be cached longer)
      motor_other_stats = fetch_motor_other_stats_cached
      formatted.merge!(motor_other_stats)

      # Lead conversion percentage
      formatted[:lead_conversion_percentage] = if formatted[:total_leads] > 0
        ((formatted[:converted_leads] / formatted[:total_leads]) * 100).round(2)
      else
        0
      end

      # Add recent items (cached separately for faster updates)
      formatted[:recent_policies] = fetch_recent_items_cached[:recent_policies]
      formatted[:recent_leads] = fetch_recent_items_cached[:recent_leads]

      # Add renewal status
      formatted[:renewal_status] = {
        'Renewed' => get_renewed_count_cached,
        'Pending' => formatted[:renewal_due_count],
        'Expired' => formatted[:expired_policies_count]
      }

      # Performance metrics
      formatted[:avg_policy_value] = if formatted[:total_policies] > 0
        (formatted[:total_premium_collected] / formatted[:total_policies]).round(0)
      else
        0
      end
      formatted[:monthly_recurring_revenue] = (formatted[:total_premium_collected] / 12.0).round(0)
      formatted[:commissions_due] = formatted[:pending_payouts]

      # Add cache metadata
      formatted[:cached_from] = 'materialized_view'
      formatted[:cache_timestamp] = stats['calculated_at']
      formatted[:cache_age_seconds] = (Time.current - Time.parse(stats['calculated_at'].to_s)).to_i

      formatted
    end

    def fetch_motor_other_stats_cached
      Rails.cache.fetch("dashboard_motor_other_stats_#{Date.current}", expires_in: 1.hour) do
        stats = { motor_count: 0, other_count: 0, motor_premium: 0, other_premium: 0 }

        # Motor insurance
        if ActiveRecord::Base.connection.table_exists?('motor_insurances')
          motor_result = ActiveRecord::Base.connection.select_one(
            'SELECT COUNT(*) as count, COALESCE(SUM(net_premium), 0) as premium FROM motor_insurances'
          )
          stats[:motor_count] = motor_result['count'].to_i
          stats[:motor_premium] = motor_result['premium'].to_f
        end

        # Other insurance
        if ActiveRecord::Base.connection.table_exists?('other_insurances')
          other_result = ActiveRecord::Base.connection.select_one(
            'SELECT COUNT(*) as count, COALESCE(SUM(net_premium), 0) as premium FROM other_insurances'
          )
          stats[:other_count] = other_result['count'].to_i
          stats[:other_premium] = other_result['premium'].to_f
        end

        stats
      end
    end

    def fetch_recent_items_cached
      Rails.cache.fetch("dashboard_recent_items_#{Time.current.to_i / 30}", expires_in: 30.seconds) do
        {
          recent_policies: DashboardUltraFastService.send(:fetch_recent_policies_cached),
          recent_leads: DashboardUltraFastService.send(:fetch_recent_leads_cached)
        }
      end
    end

    def get_renewed_count_cached
      Rails.cache.fetch("dashboard_renewed_count_#{Date.current}", expires_in: 1.hour) do
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
  end
end