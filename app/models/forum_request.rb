class ForumRequest < ApplicationRecord
  enum :status, { pending: 0, approved: 1, rejected: 2 }

  belongs_to :business_plan, optional: true
  belongs_to :forum, optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :company_name, presence: true

  scope :recent_first, -> { order(created_at: :desc) }
end
