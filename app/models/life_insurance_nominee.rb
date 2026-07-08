class LifeInsuranceNominee < ApplicationRecord
  belongs_to :life_insurance

  validates :nominee_name, presence: true
  validates :relationship, presence: true
  validates :age, presence: true, numericality: { greater_than: 0, less_than: 150 }
  validates :share_percentage, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
end
