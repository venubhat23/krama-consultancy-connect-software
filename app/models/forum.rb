class Forum < ApplicationRecord
  enum :status, { active: 0, suspended: 1 }

  belongs_to :business_plan
  has_many :chapters, dependent: :destroy
  has_many :users, dependent: :nullify
  has_many :forum_requests, dependent: :nullify
  has_many :announcements, dependent: :destroy
  has_many :support_tickets, dependent: :destroy
  has_many :events, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, on: :create

  def admin
    users.find_by(user_type: 'forum_admin')
  end

  def member_count
    users.where(user_type: 'member').count
  end

  def chapter_count
    chapters.count
  end

  def member_limit_reached?
    business_plan.member_limit.present? && member_count >= business_plan.member_limit
  end

  def chapter_limit_reached?
    business_plan.chapter_limit.present? && chapter_count >= business_plan.chapter_limit
  end

  # Creates a Forum plus its forum_admin User in a single transaction.
  # Used by both direct super-admin creation and forum-request approval.
  def self.provision!(name:, business_plan:, admin_attrs:)
    forum = nil
    transaction do
      forum = create!(name: name, business_plan: business_plan)
      User.create!(
        admin_attrs.merge(
          user_type: 'forum_admin',
          forum: forum,
          status: true
        )
      )
    end
    forum
  end

  private

  def generate_slug
    return if name.blank?
    base = name.parameterize
    candidate = base
    n = 2
    while Forum.where(slug: candidate).where.not(id: id).exists?
      candidate = "#{base}-#{n}"
      n += 1
    end
    self.slug = candidate
  end
end
