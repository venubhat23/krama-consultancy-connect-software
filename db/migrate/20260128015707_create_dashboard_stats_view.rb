class CreateDashboardStatsView < ActiveRecord::Migration[6.1]
  def up
    # Create a materialized view for ultra-fast dashboard stats
    execute <<-SQL
      CREATE MATERIALIZED VIEW IF NOT EXISTS dashboard_stats_view AS
      WITH date_ranges AS (
        SELECT
          CURRENT_DATE as today,
          CURRENT_DATE + INTERVAL '30 days' as future_30,
          DATE_TRUNC('month', CURRENT_DATE) as current_month_start,
          DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month') as last_month_start,
          DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month') + INTERVAL '1 month' - INTERVAL '1 day' as last_month_end
      )
      SELECT
        -- Timestamp for cache invalidation
        NOW() as calculated_at,

        -- Customer metrics
        (SELECT COUNT(*) FROM customers) as total_customers,
        (SELECT COUNT(*) FROM customers WHERE status = true) as active_customers,
        (SELECT COUNT(*) FROM customers WHERE created_at >= (SELECT current_month_start FROM date_ranges)) as customers_this_month,

        -- Lead metrics
        (SELECT COUNT(*) FROM leads) as total_leads,
        (SELECT COUNT(*) FROM leads WHERE current_stage = 'converted') as converted_leads,
        (SELECT COUNT(*) FROM leads WHERE current_stage IN ('lead_generated', 'follow_up', 'follow_up_successful', 'consultation_scheduled', 'one_on_one')) as pending_leads,

        -- SubAgent metrics
        (SELECT COUNT(*) FROM sub_agents) as total_affiliates,
        (SELECT COUNT(*) FROM sub_agents WHERE status = 0) as active_sub_agents,

        -- Distributor metrics
        (SELECT COUNT(*) FROM distributors) as total_distributors,

        -- Health Insurance metrics
        (SELECT COUNT(*) FROM health_insurances) as health_insurance_count,
        (SELECT COALESCE(SUM(total_premium), 0) FROM health_insurances) as health_premium_total,
        (SELECT COALESCE(SUM(sum_insured), 0) FROM health_insurances) as health_sum_insured,
        (SELECT COUNT(*) FROM health_insurances WHERE policy_end_date >= CURRENT_DATE) as health_active,
        (SELECT COUNT(*) FROM health_insurances WHERE policy_end_date < CURRENT_DATE) as health_expired,
        (SELECT COUNT(*) FROM health_insurances WHERE policy_end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days') as health_expiring,

        -- Life Insurance metrics
        (SELECT COUNT(*) FROM life_insurances) as life_insurance_count,
        (SELECT COALESCE(SUM(total_premium), 0) FROM life_insurances) as life_premium_total,
        (SELECT COALESCE(SUM(sum_insured), 0) FROM life_insurances) as life_sum_insured,
        (SELECT COUNT(*) FROM life_insurances WHERE policy_end_date >= CURRENT_DATE) as life_active,
        (SELECT COUNT(*) FROM life_insurances WHERE policy_end_date < CURRENT_DATE) as life_expired,
        (SELECT COUNT(*) FROM life_insurances WHERE policy_end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days') as life_expiring,

        -- Commission Payout metrics
        (SELECT COALESCE(SUM(payout_amount), 0) FROM commission_payouts WHERE status = 'pending') as commission_pending,
        (SELECT COALESCE(SUM(payout_amount), 0) FROM commission_payouts WHERE status = 'paid') as commission_paid,
        (SELECT COALESCE(SUM(payout_amount), 0) FROM commission_payouts) as commission_total
    SQL

    # Create index for faster refresh
    execute <<-SQL
      CREATE UNIQUE INDEX IF NOT EXISTS idx_dashboard_stats_view_calculated_at
      ON dashboard_stats_view (calculated_at);
    SQL

    # Create function to refresh the materialized view
    execute <<-SQL
      CREATE OR REPLACE FUNCTION refresh_dashboard_stats_view()
      RETURNS void AS $$
      BEGIN
        REFRESH MATERIALIZED VIEW CONCURRENTLY dashboard_stats_view;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end

  def down
    execute "DROP FUNCTION IF EXISTS refresh_dashboard_stats_view();"
    execute "DROP MATERIALIZED VIEW IF EXISTS dashboard_stats_view;"
  end
end