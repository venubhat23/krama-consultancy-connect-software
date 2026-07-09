class Event < ApplicationRecord
  enum :event_type, { meeting: 0, workshop: 1, networking: 2, other: 3, office_darshan: 4 }

  belongs_to :forum
  belongs_to :chapter, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  has_many :event_registrations, dependent: :destroy
  has_many :registrants, through: :event_registrations, source: :user

  validates :title, presence: true
  validates :starts_at, presence: true

  scope :upcoming, -> { where("starts_at >= ?", Time.current).order(:starts_at) }
  scope :past, -> { where("starts_at < ?", Time.current).order(starts_at: :desc) }

  # Visible to a chapter-scoped event feed: chapter's own events + forum-wide (chapter_id nil) events.
  def self.visible_for_chapter(chapter)
    where(chapter_id: [chapter.id, nil]).where(forum_id: chapter.forum_id)
  end

  def attendance_count
    event_registrations.where(attended: true).count
  end

  def registration_count
    event_registrations.going.count
  end

  def not_going_count
    event_registrations.not_going.count
  end

  def pending_invite_count
    event_registrations.invited.count
  end

  def thanked_count
    event_registrations.where(thanked: true).count
  end

  def upcoming?
    starts_at >= Time.current
  end

  # Upcoming events in scope for a user that they haven't RSVP'd to yet.
  def self.pending_rsvp_for(user)
    where(forum_id: user.forum_id, chapter_id: [user.chapter_id, nil])
      .upcoming
      .where.not(id: user.event_registrations.select(:event_id))
      .order(:starts_at)
  end

  # Office Darshan invites a member hasn't responded to yet — drives the dashboard banner.
  def self.pending_office_darshan_invites_for(user)
    office_darshan
      .upcoming
      .joins(:event_registrations)
      .merge(EventRegistration.invited.where(user_id: user.id))
  end
end
