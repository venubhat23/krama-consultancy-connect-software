class LifeInsuranceDocument < ApplicationRecord
  belongs_to :life_insurance
  has_one_attached :document

  validates :document_type, presence: true, inclusion: { in: ['policy_copy', 'proposal_form', 'medical_reports', 'id_proof', 'address_proof', 'other'] }
  validates :document_name, presence: true
end
