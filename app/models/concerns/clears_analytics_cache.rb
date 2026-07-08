module ClearsAnalyticsCache
  extend ActiveSupport::Concern

  included do
    after_commit :invalidate_analytics_cache
  end

  private

  def invalidate_analytics_cache
    AnalyticsCache.clear_cache('main_analytics')
  rescue => e
    Rails.logger.error "Failed to clear analytics cache: #{e.message}"
  end
end
