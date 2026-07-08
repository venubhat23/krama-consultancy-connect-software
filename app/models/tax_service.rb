class TaxService < ApplicationRecord
  belongs_to :customer

  # Validations
  validates :service_type, presence: true, inclusion: { in: ['ITR Filing', 'Tax Planning', 'GST Return', 'Tax Consultation'] }
  validates :financial_year, presence: true
  validates :filing_date, presence: true

  # Status methods (using boolean column)
  def completed?
    status == true
  end

  def pending?
    status == false || status.nil?
  end

  def mark_as_completed!
    update!(status: true)
  end

  def mark_as_pending!
    update!(status: false)
  end

  # Scopes
  scope :by_type, ->(type) { where(service_type: type) }
  scope :by_financial_year, ->(year) { where(financial_year: year) }
  scope :completed_services, -> { where(status: true) }
  scope :pending_services, -> { where(status: [false, nil]) }

  # Instance methods
  def display_name
    "#{service_type} - FY #{financial_year}"
  end

  def is_itr_filing?
    service_type == 'ITR Filing'
  end
end
