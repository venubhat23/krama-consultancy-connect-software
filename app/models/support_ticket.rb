class SupportTicket < ApplicationRecord
  enum :status, { open: 0, in_progress: 1, resolved: 2, closed: 3 }
  enum :priority, { low: 0, medium: 1, high: 2 }

  belongs_to :forum, optional: true
  belongs_to :chapter, optional: true
  belongs_to :raised_by, class_name: "User"
  has_many :replies, class_name: "SupportTicketReply", dependent: :destroy

  validates :subject, presence: true
  validates :body, presence: true

  scope :recent_first, -> { order(created_at: :desc) }
  scope :with_list_includes, -> { includes(:raised_by, :forum, :chapter) }

  # Visibility rules: raiser always sees own; chapter_admin sees their chapter's;
  # forum_admin sees their forum's; super_admin sees everything (handled by caller).
  def self.visible_to(user)
    case user.user_type
    when "chapter_admin"
      where(chapter_id: user.chapter_id).or(where(raised_by_id: user.id))
    when "forum_admin"
      where(forum_id: user.forum_id).or(where(raised_by_id: user.id))
    else
      where(raised_by_id: user.id)
    end
  end
end
