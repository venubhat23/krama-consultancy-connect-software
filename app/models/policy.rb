class Policy < ApplicationRecord
  include PgSearch::Model

  # Associations
  belongs_to :customer, counter_cache: true
  belongs_to :user
  belongs_to :insurance_company
  belongs_to :agency_broker
  has_one :life_insurance, dependent: :destroy
  has_one :health_insurance, dependent: :destroy
  has_one :motor_insurance, dependent: :destroy
  has_one :other_insurance, dependent: :destroy
  has_many_attached :documents

  # Validations
  validates :policy_number, presence: true, uniqueness: true
  validates :policy_type, presence: true, inclusion: { in: ['new_policy', 'renewal'] }
  validates :insurance_type, presence: true, inclusion: { in: ['life', 'health', 'motor', 'other'] }
  validates :payment_mode, presence: true, inclusion: { in: ['yearly', 'half_yearly', 'quarterly', 'monthly', 'single'] }
  validates :policy_start_date, presence: true
  validates :policy_end_date, presence: true
  validates :sum_insured, presence: true, numericality: { greater_than: 0 }
  validates :net_premium, presence: true, numericality: { greater_than: 0 }
  validates :total_premium, presence: true, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: [true, false] }

  # Attribute declarations for enums (required in Rails 8 when no DB column exists)
  attribute :insurance_type, :string
  attribute :payment_mode, :string

  # Enums
  enum :policy_type, { new_policy: 'new_policy', renewal: 'renewal' }
  enum :insurance_type, { life: 'life', health: 'health', motor: 'motor', other: 'other' }
  enum :payment_mode, { yearly: 'yearly', half_yearly: 'half_yearly', quarterly: 'quarterly', monthly: 'monthly', single: 'single' }

  # Scopes
  scope :active, -> { where(status: true) }
  scope :expired, -> { where('policy_end_date < ?', Date.current) }
  scope :expiring_soon, -> { where(policy_end_date: Date.current..30.days.from_now) }
  scope :by_type, ->(type) { where(insurance_type: type) }

  # Search
  pg_search_scope :search_policies,
    against: [:policy_number, :plan_name],
    associated_against: {
      customer: [:first_name, :last_name, :company_name],
      insurance_company: [:name]
    },
    using: {
      tsearch: { prefix: true, any_word: true }
    }

  # Callbacks
  before_save :calculate_total_premium

  # Instance methods
  def active?
    status && policy_end_date >= Date.current
  end

  def expired?
    policy_end_date < Date.current
  end

  def expiring_soon?
    policy_end_date.between?(Date.current, 30.days.from_now)
  end

  def days_until_expiry
    (policy_end_date - Date.current).to_i
  end

  def specific_insurance
    case insurance_type
    when 'life'
      life_insurance
    when 'health'
      health_insurance
    when 'motor'
      motor_insurance
    when 'other'
      other_insurance
    end
  end

  def policy_holder
    specific_insurance&.policy_holder
  end

  private

  def calculate_total_premium
    if net_premium.present? && gst_percentage.present?
      gst_amount = net_premium * (gst_percentage / 100.0)
      self.total_premium = net_premium + gst_amount
    end
  end
end
