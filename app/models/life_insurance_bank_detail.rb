class LifeInsuranceBankDetail < ApplicationRecord
  belongs_to :life_insurance

  validates :bank_name, presence: true
  validates :account_type, presence: true, inclusion: { in: ['savings', 'current', 'salary', 'business'] }
  validates :account_number, presence: true
  validates :ifsc_code, presence: true, format: { with: /\A[A-Z]{4}[0-9]{7}\z/, message: "Invalid IFSC code format" }
  validates :account_holder_name, presence: true
end
