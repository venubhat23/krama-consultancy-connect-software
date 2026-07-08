class UserRole < ApplicationRecord
  # Associations
  has_many :users, dependent: :nullify

  # Validations
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :status, inclusion: { in: [true, false] }
  validates :display_order, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where(status: true) }
  scope :ordered, -> { order(:display_order, :name) }

  before_save :normalize_name

  def display_name
    name.present? ? name.titleize : 'Unnamed Role'
  end

  def active?
    status == true
  end

  def self.for_select
    active.ordered.pluck(:name, :id)
  end

  private

  def normalize_name
    self.name = name.strip.titleize if name.present?
  end
end
