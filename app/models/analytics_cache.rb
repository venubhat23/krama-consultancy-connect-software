class AnalyticsCache < ApplicationRecord
  validates :cache_identifier, presence: true, uniqueness: true

  serialize :cache_data, coder: JSON

  # Cache analytics data with identifier
  def self.cache_analytics_data(identifier, data)
    record = find_by(cache_identifier: identifier)
    if record
      record.update!(cache_data: data, last_updated: Time.current)
    else
      record = create!(
        cache_identifier: identifier,
        cache_data: data,
        last_updated: Time.current
      )
    end
    record
  end

  # Get cached analytics data
  def self.get_cached_data(identifier)
    cache_record = find_by(cache_identifier: identifier)
    return nil unless cache_record

    cache_record.cache_data
  end

  # Check if cache is fresh (less than 1 hour old)
  def self.cache_fresh?(identifier, max_age = 1.hour)
    cache_record = find_by(cache_identifier: identifier)
    return false unless cache_record&.last_updated

    cache_record.last_updated > max_age.ago
  end

  # Clear specific cache
  def self.clear_cache(identifier)
    find_by(cache_identifier: identifier)&.destroy
  end

  # Clear all analytics cache
  def self.clear_all_cache
    destroy_all
  end

  # Get cache age in minutes
  def cache_age_minutes
    return nil unless last_updated
    ((Time.current - last_updated) / 1.minute).round
  end

  # Check if cache is stale
  def stale?(max_age = 1.hour)
    return true unless last_updated
    last_updated <= max_age.ago
  end
end
