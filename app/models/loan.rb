class Loan < ApplicationRecord
  belongs_to :customer

  # Validations
  validates :loan_type, presence: true, inclusion: { in: ['Personal', 'Home', 'Business'] }
  validates :loan_amount, presence: true, numericality: { greater_than: 0 }
  validates :interest_rate, presence: true, numericality: { greater_than: 0 }
  validates :loan_term, presence: true, numericality: { greater_than: 0 }
  validates :loan_date, presence: true

  # Scopes
  scope :by_type, ->(type) { where(loan_type: type) }
  scope :active_loans, -> { where(status: true) }
  scope :closed_loans, -> { where(status: false) }

  # Instance methods
  def display_name
    "#{loan_type} Loan - ₹#{loan_amount}"
  end

  def active?
    status == true
  end

  def closed?
    status == false
  end

  def status_name
    status? ? 'Active' : 'Closed'
  end

  def calculate_emi
    # Simple EMI calculation: P * r * (1 + r)^n / ((1 + r)^n - 1)
    return 0 unless loan_amount && interest_rate && loan_term

    monthly_rate = (interest_rate / 100.0) / 12
    months = loan_term * 12

    if monthly_rate == 0
      loan_amount / months
    else
      loan_amount * monthly_rate * (1 + monthly_rate)**months / ((1 + monthly_rate)**months - 1)
    end
  end
end
