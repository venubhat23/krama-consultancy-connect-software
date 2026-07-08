class Announcement < ApplicationRecord
  enum :audience, { everyone: 0, specific_forum: 1, specific_chapter: 2, specific_member: 3 }

  belongs_to :forum, optional: true
  belongs_to :chapter, optional: true
  belongs_to :target_user, class_name: "User", optional: true
  belongs_to :created_by, class_name: "User"

  validates :title, presence: true
  validates :body, presence: true
  validates :forum, presence: true, if: :specific_forum?
  validates :chapter, presence: true, if: :specific_chapter?
  validates :target_user, presence: true, if: :specific_member?

  before_validation :set_published_at, on: :create

  scope :published, -> { where.not(published_at: nil).where("published_at <= ?", Time.current) }
  scope :recent_first, -> { order(published_at: :desc, created_at: :desc) }

  # Eager-load friendly: pass the user in, not a fresh query per row.
  def self.visible_to(user)
    published
      .where(audience: audiences[:everyone])
      .or(published.where(audience: audiences[:specific_forum], forum_id: user.forum_id))
      .or(published.where(audience: audiences[:specific_chapter], chapter_id: user.chapter_id))
      .or(published.where(audience: audiences[:specific_member], target_user_id: user.id))
  end

  private

  def set_published_at
    self.published_at ||= Time.current
  end
end
