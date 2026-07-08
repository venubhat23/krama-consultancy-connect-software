# Database performance optimizations
Rails.application.configure do
  if Rails.env.production?
    # Connection pool optimization
    config.database_configuration[Rails.env]['pool'] = ENV.fetch('DB_POOL_SIZE', 20).to_i
    config.database_configuration[Rails.env]['timeout'] = ENV.fetch('DB_TIMEOUT', 5000).to_i
    config.database_configuration[Rails.env]['checkout_timeout'] = ENV.fetch('DB_CHECKOUT_TIMEOUT', 5).to_i

    # Connection reaping
    config.database_configuration[Rails.env]['reaping_frequency'] = ENV.fetch('DB_REAPING_FREQUENCY', 10).to_i

    # Prepared statements for better performance
    config.database_configuration[Rails.env]['prepared_statements'] = true

    # Enable connection verification
    config.database_configuration[Rails.env]['verify_connection'] = true
  end
end

# Query optimization settings
ActiveRecord::Base.logger.level = Logger::WARN if Rails.env.production?

# Configure query caching
ActiveRecord::Base.connection.enable_query_cache!

# Connection pool monitoring (development only)
if Rails.env.development?
  ActiveSupport::Notifications.subscribe('connection.active_record') do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    Rails.logger.debug "[DB Connection] #{event.payload[:connection_id]} - #{event.payload[:operation]}"
  end
end

# Dashboard-specific connection pool for read-only operations
if Rails.env.production?
  class DashboardConnectionPool
    class << self
      def with_dashboard_connection(&block)
        # Use a separate read-only connection for dashboard queries
        # This prevents dashboard queries from blocking write operations
        ActiveRecord::Base.connected_to(role: :reading, prevent_writes: true) do
          yield
        end
      rescue => e
        # Fall back to primary connection if read replica fails
        Rails.logger.warn "[Dashboard] Read replica failed, falling back to primary: #{e.message}"
        yield
      end
    end
  end
end