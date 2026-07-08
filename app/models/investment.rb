class Investment < ApplicationRecord
  belongs_to :customer

  # Validations
  validates :investment_type, presence: true, inclusion: { in: ['Mutual Fund', 'Gold', 'NPS', 'Bonds'] }
  validates :product_name, presence: true
  validates :investment_amount, presence: true, numericality: { greater_than: 0 }
  validates :investment_date, presence: true

  # Enums
  enum :status, { active: true, inactive: false }

  # Scopes
  scope :by_type, ->(type) { where(investment_type: type) }
  scope :active_investments, -> { where(status: true) }

  # Instance methods
  def display_name
    "#{product_name} - #{investment_type}"
  end

  def is_matured?
    maturity_date && maturity_date <= Date.current
  end
end
