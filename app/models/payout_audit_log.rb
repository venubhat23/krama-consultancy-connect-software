class PayoutAuditLog < ApplicationRecord
  include PgSearch::Model

  # Associations
  belongs_to :auditable, polymorphic: true

  # Validations
  validates :action, presence: true
  validates :auditable_type, presence: true
  validates :auditable_id, presence: true
  validates :performed_by, presence: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(performed_by: user) }
  scope :for_action, ->(action) { where(action: action) }
  scope :for_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }

  # Search configuration
  pg_search_scope :search_logs,
    against: [:action, :performed_by, :notes],
    using: {
      tsearch: { prefix: true, any_word: true }
    }

  # Instance methods
  def formatted_changes
    return {} unless self[:changes].present?

    formatted = {}
    self[:changes].each do |key, value|
      if value.is_a?(Array) && value.length == 2
        formatted[key] = {
          from: value[0],
          to: value[1]
        }
      else
        formatted[key] = value
      end
    end
    formatted
  end

  def change_summary
    return 'No changes' unless changes.present?

    changes.map do |key, value|
      if value.is_a?(Array) && value.length == 2
        "#{key.humanize}: #{value[0]} → #{value[1]}"
      else
        "#{key.humanize}: #{value}"
      end
    end.join(', ')
  end

  def user_info
    if performed_by.include?('@')
      performed_by
    else
      "System (#{performed_by})"
    end
  end

  # Class methods
  def self.create_log(auditable, action, performer, changes = {}, notes = nil, ip_address = nil)
    create!(
      auditable: auditable,
      action: action,
      performed_by: performer,
      changes: changes,
      notes: notes,
      ip_address: ip_address
    )
  end

  def self.activity_summary(start_date, end_date)
    logs = where(created_at: start_date..end_date)

    {
      total_actions: logs.count,
      actions_by_type: logs.group(:action).count,
      actions_by_user: logs.group(:performed_by).count,
      actions_by_day: logs.group_by_day(:created_at).count,
      most_active_users: logs.group(:performed_by).count.sort_by { |_, count| -count }.first(5),
      recent_activities: logs.recent.limit(10).includes(:auditable)
    }
  end

  def self.user_activity(user, limit = 50)
    for_user(user).recent.limit(limit).includes(:auditable)
  end
end