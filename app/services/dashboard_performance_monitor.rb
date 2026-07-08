class DashboardPerformanceMonitor
  include ActiveSupport::NumberHelper

  class << self
    def track_dashboard_load(start_time:, end_time:, cache_hit:, data_source:)
      duration_ms = ((end_time - start_time) * 1000).round(2)

      # Log performance metrics
      Rails.logger.info "[DashboardPerf] Load completed in #{duration_ms}ms (#{data_source}, cache_hit: #{cache_hit})"

      # Store metrics for analysis
      store_metrics(duration_ms, cache_hit, data_source)

      # Alert if performance is degraded
      alert_if_slow(duration_ms, data_source)

      duration_ms
    end

    def performance_report
      {
        last_24h: get_performance_stats(24.hours.ago),
        last_hour: get_performance_stats(1.hour.ago),
        current_cache_status: get_cache_status,
        slow_queries: get_slow_queries,
        recommendations: get_performance_recommendations
      }
    end

    def health_check
      start_time = Time.current

      # Test different cache layers
      results = {}

      # Memory cache test
      begin
        DashboardTieredCacheService.fetch_stats(mode: :instant)
        results[:memory_cache] = { status: :ok, response_time: (Time.current - start_time) * 1000 }
      rescue => e
        results[:memory_cache] = { status: :error, error: e.message }
      end

      # Database view test
      begin
        DashboardInstantService.fetch_stats
        results[:database_view] = { status: :ok }
      rescue => e
        results[:database_view] = { status: :error, error: e.message }
      end

      # Full computation test (should be fast due to optimization)
      begin
        DashboardUltraFastService.fetch_stats
        results[:full_computation] = { status: :ok }
      rescue => e
        results[:full_computation] = { status: :error, error: e.message }
      end

      results[:overall_status] = results.values.all? { |r| r[:status] == :ok } ? :healthy : :degraded
      results[:total_check_time] = (Time.current - start_time) * 1000

      results
    end

    private

    def store_metrics(duration_ms, cache_hit, data_source)
      # Store in Rails cache for quick access
      metrics_key = "dashboard_metrics_#{Date.current}"
      current_metrics = Rails.cache.read(metrics_key) || []

      current_metrics << {
        timestamp: Time.current.to_i,
        duration_ms: duration_ms,
        cache_hit: cache_hit,
        data_source: data_source
      }

      # Keep only last 1000 entries
      current_metrics = current_metrics.last(1000)

      Rails.cache.write(metrics_key, current_metrics, expires_in: 25.hours)
    end

    def alert_if_slow(duration_ms, data_source)
      # Alert thresholds
      thresholds = {
        'materialized_view' => 50,    # 50ms for view queries
        'tiered_cache' => 10,         # 10ms for cached data
        'full_computation' => 500     # 500ms for full computation
      }

      threshold = thresholds[data_source] || 100

      if duration_ms > threshold
        Rails.logger.warn "[DashboardPerf] SLOW LOAD: #{duration_ms}ms (threshold: #{threshold}ms, source: #{data_source})"

        # Could integrate with alerting service here
        # SlackNotifier.notify_slow_dashboard(duration_ms, data_source) if Rails.env.production?
      end
    end

    def get_performance_stats(since)
      metrics_key = "dashboard_metrics_#{Date.current}"
      all_metrics = Rails.cache.read(metrics_key) || []

      recent_metrics = all_metrics.select { |m| Time.at(m[:timestamp]) > since }
      return {} if recent_metrics.empty?

      durations = recent_metrics.map { |m| m[:duration_ms] }
      cache_hits = recent_metrics.count { |m| m[:cache_hit] }

      {
        total_requests: recent_metrics.size,
        avg_response_time: durations.sum / durations.size,
        median_response_time: durations.sort[durations.size / 2],
        max_response_time: durations.max,
        min_response_time: durations.min,
        cache_hit_rate: (cache_hits.to_f / recent_metrics.size * 100).round(1),
        data_sources: recent_metrics.group_by { |m| m[:data_source] }.transform_values(&:size)
      }
    end

    def get_cache_status
      {
        memory_cache_size: Thread.current[:dashboard_tier_cache].present? ? 1 : 0,
        redis_cache_keys: (Rails.cache.respond_to?(:redis) ? (Rails.cache.redis.keys('dashboard*').size rescue 0) : 0),
        materialized_view_age: get_view_age,
        cache_warming_active: Rails.cache.exist?('dashboard_cache_warmer_active')
      }
    end

    def get_view_age
      begin
        result = ActiveRecord::Base.connection.select_one(
          'SELECT calculated_at FROM dashboard_stats_view LIMIT 1'
        )
        return 'N/A' unless result

        age_seconds = (Time.current - Time.parse(result['calculated_at'].to_s)).to_i
        "#{age_seconds} seconds ago"
      rescue
        'View not available'
      end
    end

    def get_slow_queries
      # This would integrate with your query monitoring tool
      # For now, return placeholder
      []
    end

    def get_performance_recommendations
      recommendations = []
      health = health_check

      if health[:overall_status] == :degraded
        recommendations << "System health degraded - check error logs"
      end

      if health[:memory_cache][:response_time]&.> 5
        recommendations << "Memory cache response time high - consider restarting processes"
      end

      cache_status = get_cache_status
      if cache_status[:materialized_view_age] =~ /(\d+) seconds/
        age = $1.to_i
        if age > 600 # 10 minutes
          recommendations << "Materialized view is stale - consider refreshing"
        end
      end

      stats = get_performance_stats(1.hour.ago)
      if stats[:cache_hit_rate]&.< 50
        recommendations << "Low cache hit rate - check cache configuration"
      end

      recommendations.empty? ? ["Performance is optimal"] : recommendations
    end
  end
end