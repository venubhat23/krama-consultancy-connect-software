class DashboardTieredCacheService
  # Multi-tier caching: Memory -> Redis -> Database View -> Full Computation

  MEMORY_TTL = 10.seconds
  REDIS_TTL = 1.minute
  VIEW_TTL = 5.minutes

  class << self
    def fetch_stats(mode: :auto)
      case mode
      when :instant
        fetch_instant_stats
      when :real_time
        fetch_real_time_stats
      when :background
        fetch_background_stats
      else
        fetch_auto_stats
      end
    end

    private

    # Tier 1: Memory cache (fastest, ~1ms)
    def fetch_instant_stats
      memory_stats = get_memory_cache
      return memory_stats if memory_stats.present?

      # Fall back to Redis
      redis_stats = get_redis_cache
      if redis_stats.present?
        set_memory_cache(redis_stats)
        return redis_stats
      end

      # Fall back to materialized view
      view_stats = DashboardInstantService.fetch_stats
      set_memory_cache(view_stats)
      set_redis_cache(view_stats)
      view_stats
    end

    # Tier 2: Real-time partial updates (~50ms)
    def fetch_real_time_stats
      base_stats = fetch_instant_stats

      # Only update frequently changing data
      real_time_updates = fetch_real_time_updates

      base_stats.merge(real_time_updates)
    end

    # Tier 3: Background computation (for accuracy)
    def fetch_background_stats
      DashboardUltraFastService.fetch_stats
    end

    # Auto mode: Choose best strategy based on load and freshness
    def fetch_auto_stats
      # Check system load
      if high_load?
        fetch_instant_stats
      else
        fetch_real_time_stats
      end
    end

    # Memory cache (process-local)
    def get_memory_cache
      cache = Thread.current[:dashboard_tier_cache]
      return nil unless cache.present?
      return nil if cache[:expires_at] < Time.current

      cache[:data]
    end

    def set_memory_cache(data)
      Thread.current[:dashboard_tier_cache] = {
        data: data,
        expires_at: MEMORY_TTL.from_now
      }
    end

    # Redis cache (shared across processes)
    def get_redis_cache
      Rails.cache.read(redis_cache_key)
    end

    def set_redis_cache(data)
      Rails.cache.write(redis_cache_key, data, expires_in: REDIS_TTL)
    end

    def redis_cache_key
      "dashboard_tier_#{Date.current}_#{Time.current.to_i / 60}" # 1-minute buckets
    end

    # Real-time updates for frequently changing data
    def fetch_real_time_updates
      Rails.cache.fetch("dashboard_realtime_#{Time.current.to_i / 30}", expires_in: 30.seconds) do
        {
          recent_policies: fetch_very_recent_policies,
          recent_leads: fetch_very_recent_leads,
          active_users: fetch_active_users_count,
          pending_notifications: fetch_pending_notifications_count
        }
      end
    end

    def fetch_very_recent_policies
      # Only last hour policies for real-time feel
      sql = <<-SQL
        SELECT
          'Health Insurance' as type,
          h.policy_number,
          h.net_premium as total_premium,
          h.created_at,
          CASE
            WHEN c.customer_type = 'individual' THEN TRIM(CONCAT(c.first_name, ' ', COALESCE(c.middle_name, ''), ' ', c.last_name))
            ELSE c.company_name
          END as customer_name
        FROM health_insurances h
        LEFT JOIN customers c ON h.customer_id = c.id
        WHERE h.created_at >= NOW() - INTERVAL '1 hour'
        ORDER BY h.created_at DESC
        LIMIT 5
      SQL

      ActiveRecord::Base.connection.select_all(sql).map do |row|
        {
          type: row['type'],
          customer: row['customer_name'] || 'Unknown',
          policy_number: row['policy_number'],
          premium: row['total_premium'].to_f,
          date: row['created_at']
        }
      end
    end

    def fetch_very_recent_leads
      Lead.select(:id, :lead_id, :name, :current_stage, :created_at)
          .where('created_at >= ?', 1.hour.ago)
          .order(created_at: :desc)
          .limit(5)
          .to_a
    end

    def fetch_active_users_count
      # Count of users active in last 15 minutes
      # This would require session tracking
      Rails.cache.fetch("active_users_#{Time.current.to_i / 900}", expires_in: 15.minutes) do
        # Placeholder - implement based on your session tracking
        0
      end
    end

    def fetch_pending_notifications_count
      # Count of unread notifications
      Rails.cache.fetch("pending_notifications_#{Time.current.to_i / 60}", expires_in: 1.minute) do
        # Placeholder - implement based on your notification system
        0
      end
    end

    def high_load?
      # Simple load detection based on active database connections
      pool = ActiveRecord::Base.connection_pool
      active_connections = pool.connections.count(&:in_use?)
      total_connections = pool.size

      # Consider high load if >70% connections are active
      (active_connections.to_f / total_connections) > 0.7
    end
  end
end