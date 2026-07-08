class Chapter < ApplicationRecord
  enum :status, { active: 0, inactive: 1 }

  belongs_to :forum
  has_many :users, dependent: :nullify
  has_many :announcements, dependent: :destroy
  has_many :support_tickets, dependent: :destroy
  has_many :events, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :forum_id, case_sensitive: false }
  validate :within_forum_chapter_limit, on: :create

  scope :with_member_counts, -> {
    left_joins(:users)
      .select("chapters.*, COUNT(users.id) FILTER (WHERE users.user_type = 'member') AS members_count")
      .group("chapters.id")
  }

  def admin
    users.find_by(user_type: 'chapter_admin')
  end

  def member_count
    users.where(user_type: 'member').count
  end

  private

  def within_forum_chapter_limit
    return unless forum
    if forum.chapter_limit_reached?
      errors.add(:base, "#{forum.name} has reached its #{forum.business_plan.name} plan limit of #{forum.business_plan.chapter_limit} chapters.")
    end
  end
end
