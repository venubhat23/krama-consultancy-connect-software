class BrokerCode < ApplicationRecord
  belongs_to :broker

  validates :broker_code, presence: true, uniqueness: { case_sensitive: false }, length: { minimum: 2, maximum: 50 }
  validates :status, inclusion: { in: [true, false] }

  scope :active, -> { where(status: true) }
  scope :inactive, -> { where(status: false) }
  scope :by_broker, ->(broker_id) { where(broker_id: broker_id) }
  scope :by_company, ->(company_name) { where(company_name: company_name) }

  before_validation :set_default_status, on: :create

  def display_name
    "#{broker.name} - #{broker_code}"
  end

  def status_badge
    status? ? 'Active' : 'Inactive'
  end

  def status_color
    status? ? 'success' : 'secondary'
  end

  private

  def set_default_status
    self.status = true if status.nil?
  end
end