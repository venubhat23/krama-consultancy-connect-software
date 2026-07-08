class Event < ApplicationRecord
  enum :event_type, { meeting: 0, workshop: 1, networking: 2, other: 3 }

  belongs_to :forum
  belongs_to :chapter, optional: true
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
    event_registrations.count
  end
end
