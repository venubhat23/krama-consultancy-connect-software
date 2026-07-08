# Memory optimization for production environment
if Rails.env.production?
  # Skip database operations during asset precompilation and database tasks
  skip_db = ENV['RAILS_ASSETS_PRECOMPILE'].present? ||
            ENV['DATABASE_URL'].blank? ||
            (defined?(Rake) && Rake.application.top_level_tasks.any? { |task|
              task.include?('assets:') || task.include?('db:')
            })

  unless skip_db
    # Reduce ActiveRecord connection pool for free tier
    Rails.application.config.after_initialize do
      begin
        ActiveRecord::Base.connection_pool.disconnect!
      rescue => e
        Rails.logger.info "Skipping connection pool disconnect: #{e.message}"
      end

      ActiveSupport.on_load(:active_record) do
        begin
          # Get database configuration
          db_config = Rails.application.config.database_configuration[Rails.env]

          # Handle multi-database or simple configuration
          config = if db_config.is_a?(Hash) && db_config['primary']
            db_config['primary'].dup
          else
            db_config.dup
          end

          config['pool'] = ENV.fetch("RAILS_MAX_THREADS", 2).to_i
          ActiveRecord::Base.establish_connection(config)
        rescue => e
          Rails.logger.error "Failed to optimize database connection: #{e.message}"
        end
      end
    end
  end

  # Garbage collection tuning for low memory environments
  if ENV['RUBY_GC_HEAP_GROWTH_FACTOR'].blank?
    ENV['RUBY_GC_HEAP_GROWTH_FACTOR'] = '1.25'
  end

  if ENV['RUBY_GC_MALLOC_LIMIT'].blank?
    ENV['RUBY_GC_MALLOC_LIMIT'] = '16000000'
  end

  if ENV['RUBY_GC_HEAP_FREE_SLOTS'].blank?
    ENV['RUBY_GC_HEAP_FREE_SLOTS'] = '4096'
  end

  # Disable Ahoy tracking if it's causing memory issues
  if defined?(Ahoy)
    Ahoy.quiet = true  # Reduce logging

    # Skip tracking for admin panel to save memory
    Ahoy.exclude_method = lambda do |controller, request|
      controller.class.name.start_with?("Admin::")
    end
  end
end

# Query optimization for leads
if defined?(Lead)
  Rails.application.config.to_prepare do
    Lead.class_eval do
      # Add database indexes suggestion comment
      # Run these migrations to improve search performance:
      # add_index :leads, :contact_number
      # add_index :leads, :email
      # add_index :leads, :current_stage
      # add_index :leads, :lead_source
      # add_index :leads, :product_category
      # add_index :leads, :product_subcategory
      # add_index :leads, :converted_customer_id
      # add_index :leads, [:first_name, :last_name]
      # add_index :leads, :company_name

      # Optimize search scope to use simpler queries
      scope :simple_search, ->(query) {
        if query.present?
          where(
            "LOWER(name) LIKE LOWER(?) OR
             LOWER(contact_number) LIKE LOWER(?) OR
             LOWER(email) LIKE LOWER(?) OR
             LOWER(first_name) LIKE LOWER(?) OR
             LOWER(last_name) LIKE LOWER(?) OR
             LOWER(company_name) LIKE LOWER(?) OR
             LOWER(lead_id) LIKE LOWER(?)",
            "%#{query}%", "%#{query}%", "%#{query}%",
            "%#{query}%", "%#{query}%", "%#{query}%", "%#{query}%"
          )
        else
          all
        end
      }
    end
  end
end