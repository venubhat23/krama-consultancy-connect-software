class ClientService < ApplicationRecord
  belongs_to :customer
  belongs_to :sub_agent, class_name: 'SubAgent', optional: true
  belongs_to :distributor, optional: true

  STATUSES = %w[pending in_progress completed cancelled].freeze

  SERVICE_TYPES = {
    'taxation_itr'              => 'ITR Filing',
    'taxation_tax_planning'     => 'Tax Planning',
    'loans_personal'            => 'Personal Loan',
    'loans_home'                => 'Home Loan',
    'loans_mortgage'            => 'Mortgage Loan',
    'loans_business'            => 'Business Loan',
    'travel_domestic'           => 'Domestic Travel',
    'travel_international'      => 'International Travel',
    'credit_card_rewards'       => 'Rewards Card',
    'credit_card_business'      => 'Business Card',
    'credit_card_travel'        => 'Travel Card',
    'investments_mutual_fund'   => 'Mutual Fund',
    'investments_fd'            => 'Fixed Deposit (FD)',
    'investments_other'         => 'Other Investment'
  }.freeze

  CATEGORY_LABELS = {
    'taxation'     => 'Taxation',
    'loans'        => 'Loans',
    'travel'       => 'Travel',
    'credit_card'  => 'Credit Card',
    'investments'  => 'Investments'
  }.freeze

  CATEGORY_ICONS = {
    'taxation'    => 'bi-calculator',
    'loans'       => 'bi-cash-stack',
    'travel'      => 'bi-airplane',
    'credit_card' => 'bi-credit-card',
    'investments' => 'bi-graph-up'
  }.freeze

  TYPES_BY_CATEGORY = {
    'taxation'    => %w[taxation_itr taxation_tax_planning],
    'loans'       => %w[loans_personal loans_home loans_mortgage loans_business],
    'travel'      => %w[travel_domestic travel_international],
    'credit_card' => %w[credit_card_rewards credit_card_business credit_card_travel],
    'investments' => %w[investments_mutual_fund investments_fd investments_other]
  }.freeze

  validates :customer_id, presence: true
  validates :service_type, presence: true, inclusion: { in: SERVICE_TYPES.keys }
  validates :service_category, presence: true, inclusion: { in: CATEGORY_LABELS.keys }
  validates :status, inclusion: { in: STATUSES }

  before_validation :set_category_from_type

  scope :by_type,     ->(t) { where(service_type: t) }
  scope :by_category, ->(c) { where(service_category: c) }

  def service_type_label
    SERVICE_TYPES[service_type] || service_type.humanize
  end

  def category_label
    CATEGORY_LABELS[service_category] || service_category.humanize
  end

  def status_badge_class
    case status
    when 'pending'     then 'bg-warning text-dark'
    when 'in_progress' then 'bg-info'
    when 'completed'   then 'bg-success'
    when 'cancelled'   then 'bg-secondary'
    else 'bg-light text-dark'
    end
  end

  private

  def set_category_from_type
    return if service_type.blank?
    self.service_category = service_type.split('_').first == 'credit' ? 'credit_card' : service_type.split('_').first
    # handle credit_card prefix
    TYPES_BY_CATEGORY.each do |cat, types|
      self.service_category = cat if types.include?(service_type)
    end
  end
end
