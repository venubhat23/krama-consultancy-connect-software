class HealthInsuranceMember < ApplicationRecord
  belongs_to :health_insurance

  validates :member_name, presence: true
  validates :age, presence: true, numericality: { greater_than: 0, less_than: 120 }
  validates :relationship, presence: true
  validates :sum_insured, presence: true, numericality: { greater_than: 0 }

  RELATIONSHIPS = ['Self', 'Spouse', 'Son', 'Daughter', 'Father', 'Mother', 'Brother', 'Sister', 'Other'].freeze
end
