class MotorInsuranceNominee < ApplicationRecord
  belongs_to :motor_insurance

  validates :nominee_name, presence: true
  validates :relationship, presence: true, inclusion: {
    in: ['father', 'mother', 'spouse', 'son', 'daughter', 'brother', 'sister', 'other'],
    message: "must be a valid relationship"
  }
  validates :age, presence: true, numericality: { greater_than: 0, less_than: 150 }
  validates :share_percentage, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }

  RELATIONSHIPS = ['father', 'mother', 'spouse', 'son', 'daughter', 'brother', 'sister', 'other'].freeze
end
