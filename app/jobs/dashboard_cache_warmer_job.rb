class DashboardCacheWarmerJob < ApplicationJob
  queue_as :default

  def perform
    # Preload dashboard cache for common date ranges
    Rails.logger.info "[DashboardCache] Starting cache warming at #{Time.current}"

    start_time = Time.current
    current_year = Date.current.year

    # Warm up cache for common filters
    filters_to_warm = [
      # Current year
      [Date.new(current_year, 1, 1), Date.new(current_year, 12, 31)],
      # Current month
      [Date.current.beginning_of_month, Date.current.end_of_month],
      # Last month
      [1.month.ago.beginning_of_month, 1.month.ago.end_of_month],
      # Last 3 months
      [3.months.ago.beginning_of_month, Date.current.end_of_month]
    ]

    dashboard_controller = DashboardController.new
    cache_gen = Rails.cache.read("dashboard_cache_gen") || "0"

    filters_to_warm.each do |start_date, end_date|
      cache_key = "dashboard_data_#{cache_gen}_#{start_date}_#{end_date}_v6"

      unless Rails.cache.exist?(cache_key)
        Rails.logger.info "[DashboardCache] Warming cache for #{start_date} to #{end_date}"
        Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
          dashboard_controller.send(:get_filtered_dashboard_data, start_date, end_date)
        end
      end
    end

    # Warm up filter-independent data
    filter_independent_cache_key = "dashboard_filter_independent_#{Date.current}_v3"
    unless Rails.cache.exist?(filter_independent_cache_key)
      Rails.logger.info "[DashboardCache] Warming filter-independent cache"
      Rails.cache.fetch(filter_independent_cache_key, expires_in: 2.minutes) do
        dashboard_controller.send(:load_filter_independent_data)
      end
    end

    duration = Time.current - start_time
    Rails.logger.info "[DashboardCache] Cache warmed successfully in #{duration.round(2)} seconds"

    # Schedule next run in 3 minutes
    DashboardCacheWarmerJob.set(wait: 3.minutes).perform_later

    { success: true, duration: duration }
  rescue => e
    Rails.logger.error "[DashboardCache] Cache warming failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    # Retry in 1 minute if failed
    DashboardCacheWarmerJob.set(wait: 1.minute).perform_later
  end
end