class AgencyCode < ApplicationRecord
  include InsuranceCompanyConstants

  # Relationships
  belongs_to :broker, optional: true

  # Validations
  validates :insurance_type, presence: true, inclusion: { in: ['Health Insurance', 'Life Insurance', 'Motor and Other Insurance'] }
  validates :company_name, presence: true
  validates :agent_name, presence: true
  validates :code, presence: true, uniqueness: { scope: [:company_name, :insurance_type] }

  # Custom validation to ensure company_name is from predefined list

  # Scopes for filtering
  scope :by_insurance_type, ->(type) { where(insurance_type: type) if type.present? }
  scope :by_company, ->(company) { where(company_name: company) if company.present? }
  scope :search, ->(term) {
    if term.present?
      joins("LEFT JOIN brokers ON agency_codes.broker_id = brokers.id")
        .where("company_name ILIKE ? OR agent_name ILIKE ? OR code ILIKE ? OR brokers.name ILIKE ?",
               "%#{term}%", "%#{term}%", "%#{term}%", "%#{term}%")
    end
  }

  # Instance methods
  def display_name
    "#{company_name} - #{agent_name} (#{insurance_type})"
  end

  private
end
