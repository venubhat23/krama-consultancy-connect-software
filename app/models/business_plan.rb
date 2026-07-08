class BusinessPlan < ApplicationRecord
  has_many :forums, dependent: :restrict_with_error
  has_many :forum_requests, dependent: :nullify

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :chapter_limit, numericality: { greater_than: 0 }, allow_nil: true
  validates :member_limit, numericality: { greater_than: 0 }, allow_nil: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }

  def unlimited_chapters?
    chapter_limit.nil?
  end

  def unlimited_members?
    member_limit.nil?
  end
end
