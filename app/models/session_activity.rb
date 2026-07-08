class SessionActivity < ApplicationRecord
  belongs_to :user

  # Activity types
  ACTIVITY_TYPES = ['login', 'logout'].freeze

  validates :activity_type, inclusion: { in: ACTIVITY_TYPES }
  validates :occurred_at, presence: true

  scope :recent, -> { order(occurred_at: :desc) }
  scope :logins, -> { where(activity_type: 'login') }
  scope :logouts, -> { where(activity_type: 'logout') }
  scope :for_date_range, ->(from, to) { where(occurred_at: from..to) }

  # Create login activity
  def self.track_login(user, request)
    create!(
      user: user,
      activity_type: 'login',
      occurred_at: Time.current,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      session_id: request.session.id.to_s
    )
  end

  # Create logout activity
  def self.track_logout(user, request)
    create!(
      user: user,
      activity_type: 'logout',
      occurred_at: Time.current,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      session_id: request.session.id.to_s
    )
  end

  # Get combined activities for display
  def self.combined_activities(date_range = 30.days)
    activities = for_date_range(date_range.ago, Time.current)
                 .includes(:user)
                 .recent
                 .limit(50)

    # Convert to standardized format for display
    activities.map do |activity|
      {
        user: activity.user,
        activity_type: activity.activity_type,
        occurred_at: activity.occurred_at,
        ip_address: activity.ip_address,
        user_agent: activity.user_agent,
        session_id: activity.session_id
      }
    end
  end
end
