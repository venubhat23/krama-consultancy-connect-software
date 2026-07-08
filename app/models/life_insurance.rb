class LifeInsurance < ApplicationRecord
  include PgSearch::Model
  include InsuranceCompanyConstants
  include DashboardOptimizable
  include ClearsAnalyticsCache

  # Associations
  belongs_to :customer, counter_cache: :policies_count
  belongs_to :sub_agent, class_name: 'SubAgent', optional: true
  belongs_to :distributor
  belongs_to :agency_code, optional: true
  belongs_to :broker, optional: true
  # Note: investor association not needed - commission is collectively distributed
  # ActiveStorage associations for backward compatibility with agent API
  has_many_attached :documents
  has_many_attached :policy_documents
  has_many :uploaded_documents, as: :documentable, class_name: 'Document', dependent: :destroy
  has_many :policy_documents_records, -> { where(policy_type: 'life') },
           class_name: 'PolicyDocument',
           foreign_key: 'policy_id',
           dependent: :destroy

  # R2 File Storage fields for main policy document
  # Columns: main_policy_document_key, main_policy_document_filename, main_policy_document_content_type, main_policy_document_size

  # Virtual attribute for file upload handling (not stored in database)
  attr_accessor :main_policy_document

  # Renewal relationships
  belongs_to :original_policy, class_name: 'LifeInsurance', foreign_key: 'original_policy_id', optional: true
  has_one :renewal_policy, class_name: 'LifeInsurance', foreign_key: 'original_policy_id', dependent: :destroy

  # New relationships for API structure
  has_many :life_insurance_nominees, dependent: :destroy
  has_many :life_insurance_bank_details, dependent: :destroy
  has_many :life_insurance_documents, dependent: :destroy
  has_many :commission_payouts, -> { where(policy_type: 'life') }, foreign_key: 'policy_id', dependent: :destroy

  accepts_nested_attributes_for :life_insurance_nominees, allow_destroy: true
  accepts_nested_attributes_for :life_insurance_bank_details, allow_destroy: true
  accepts_nested_attributes_for :life_insurance_documents, allow_destroy: true
  accepts_nested_attributes_for :uploaded_documents, allow_destroy: true, reject_if: :all_blank

  # Validations
  validates :policy_holder, presence: true
  validates :insurance_company_name, presence: true
  validates :policy_type, presence: true, inclusion: { in: ['New', 'Renewal'] }
  validates :policy_booking_date, presence: true
  validates :policy_start_date, presence: true
  validates :policy_end_date, presence: true
  validates :payment_mode, presence: true
  validates :sum_insured, presence: true, numericality: { greater_than: 0 }
  validates :net_premium, presence: true, numericality: { greater_than: 0 }
  validates :first_year_gst_percentage, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :total_premium, presence: true, numericality: { greater_than: 0 }
  validates :policy_term, presence: true, numericality: { greater_than: 0 }
  validates :distributor_id, presence: true
  # investor_id removed - commission is collectively distributed
  validate :agency_code_must_exist

  # Custom validation
  validate :company_name_must_be_valid
  validate :end_date_after_start_date

  # Callbacks
  after_create :create_structured_payout

  # Enums for dropdowns
  POLICY_TYPES = ['New', 'Renewal'].freeze
  PAYMENT_MODES = ['Yearly', 'Half-Yearly', 'Quarterly', 'Monthly', 'Single'].freeze
  RELATIONSHIPS = ['Self', 'Spouse', 'Father', 'Mother', 'Son', 'Daughter', 'Brother', 'Sister', 'Other'].freeze
  ACCOUNT_TYPES = ['Savings', 'Current', 'Salary', 'Business'].freeze
  DOCUMENT_TYPES = ['PAN', 'Aadhaar', 'KYC', 'Payment Receipt', 'Medical Report', 'Other'].freeze

  # Scopes
  scope :active, -> { where('policy_end_date >= ?', Date.current) }
  scope :expired, -> { where('policy_end_date < ?', Date.current) }
  scope :expiring_soon, -> { where(policy_end_date: Date.current..30.days.from_now) }
  scope :new_policies, -> { where(policy_type: 'New') }
  scope :renewals, -> { where(policy_type: 'Renewal') }

  # Search
  pg_search_scope :search_life_policies,
    against: [:policy_number, :plan_name, :insurance_company_name, :insured_name],
    associated_against: {
      customer: [:first_name, :last_name, :company_name]
    },
    using: {
      tsearch: { prefix: true, any_word: true }
    }

  # Callbacks
  before_save :calculate_totals
  before_validation :set_policy_term_from_dates
  before_validation :normalize_numeric_fields
  before_validation :set_default_premium_payment_term
  after_save :set_notification_dates
  before_create :inherit_customer_lead_id
  before_create :set_product_through_dr
  after_create :create_commission_payouts
  after_create :create_lead_record

  # Virtual attribute for text-based sum insured input
  attr_accessor :sum_insured_text

  # Instance methods
  def active?
    policy_end_date.present? && policy_end_date >= Date.current
  end

  def expired?
    policy_end_date.blank? || policy_end_date < Date.current
  end

  def expiring_soon?
    policy_end_date.present? && policy_end_date.between?(Date.current, 30.days.from_now)
  end

  def days_until_expiry
    (policy_end_date - Date.current).to_i
  end

  def client_name
    customer.display_name
  end

  def affiliate_name
    sub_agent ? sub_agent.display_name : 'Self'
  end

  def total_rider_amount
    # Rider functionality removed - no rider columns exist in database
    0
  end

  def status
    return 'expired' if expired?
    return 'expiring_soon' if expiring_soon?
    'active'
  end

  def policy_holder_options
    options = [['Self', 'Self']]
    if customer&.family_members&.any?
      customer.family_members.each do |member|
        options << [member.full_name, member.id.to_s]
      end
    end
    options
  end

  def notifications_due_today
    return [] unless notification_dates.present?

    notification_list = JSON.parse(notification_dates)
    today = Date.current.to_s

    notification_list.select { |notification| notification['date'] == today }
  end

  # Sum insured text handling methods
  def sum_insured_display_text
    return '' if sum_insured.blank?

    amount = sum_insured.to_f

    if amount >= 10000000 # 1 crore or more
      crores = amount / 10000000
      if crores == crores.to_i
        "#{crores.to_i} crore#{crores.to_i == 1 ? '' : 's'}"
      else
        "#{crores} crore#{crores == 1.0 ? '' : 's'}"
      end
    elsif amount >= 100000 # 1 lakh or more
      lakhs = amount / 100000
      if lakhs == lakhs.to_i
        "#{lakhs.to_i} lakh#{lakhs.to_i == 1 ? '' : 's'}"
      else
        "#{lakhs} lakh#{lakhs == 1.0 ? '' : 's'}"
      end
    else
      "₹#{amount.to_i}"
    end
  end

  def sum_insured_text=(value)
    return if value.blank?

    @sum_insured_text = value
    self.sum_insured = parse_amount_text(value)
  end

  def sum_insured_text
    @sum_insured_text || sum_insured_display_text
  end

  # DrWise vs Non-DrWise classification
  def drwise_policy?
    # DrWise: Admin Added policies (is_admin_added: true AND others false)
    is_admin_added? && !is_customer_added? && !is_agent_added?
  end

  def non_drwise_policy?
    # Non-DrWise: Customer Added OR Agent Added policies
    (is_customer_added? && !is_admin_added? && !is_agent_added?) ||
    (is_agent_added? && !is_customer_added? && !is_admin_added?)
  end

  # Renewal methods
  def is_renewal?
    policy_type == 'Renewal' || original_policy_id.present?
  end

  def has_been_renewed?
    is_renewed == true || renewal_policy.present?
  end

  def can_be_renewed?
    return false if is_renewal? # Renewal policies cannot be renewed again
    return false if has_been_renewed? # Already renewed policies cannot be renewed again
    return false if policy_end_date.blank? # Cannot renew without end date

    # Can renew if policy expires within 60 days
    policy_end_date <= 60.days.from_now
  end

  def renewal_status_text
    if has_been_renewed?
      'Renewed'
    elsif can_be_renewed?
      'Can Renew'
    elsif is_renewal?
      'Renewal Policy'
    else
      'Not Eligible'
    end
  end

  def policy_classification
    if drwise_policy?
      'DrWise'
    elsif non_drwise_policy?
      'Non-DrWise'
    else
      'Unknown'
    end
  end

  def policy_classification_badge_class
    case policy_classification
    when 'DrWise'
      'bg-success text-white'  # Green for DrWise
    when 'Non-DrWise'
      'bg-warning text-dark'   # Orange/Yellow for Non-DrWise
    else
      'bg-secondary text-white' # Gray for Unknown
    end
  end

  def self.all_notifications_due_today
    notifications = []

    all.each do |insurance|
      insurance.notifications_due_today.each do |notification|
        notifications << {
          id: "#{insurance.id}_#{notification['type']}",
          type: notification['type'],
          title: notification['title'],
          message: notification['message'],
          date: notification['date'],
          insurance_id: insurance.id,
          insurance_type: 'life'
        }
      end
    end

    notifications
  end

  # R2 Direct Upload Methods for main policy document
  def upload_main_policy_to_r2(file)
    result = R2Service.upload(file, folder: "life_insurance/#{id}")

    if result[:error]
      errors.add(:main_policy_document, "Upload failed: #{result[:error]}")
      return false
    end

    # Store R2 file information
    update!(
      main_policy_document_key: result[:key],
      main_policy_document_filename: result[:filename],
      main_policy_document_content_type: result[:content_type],
      main_policy_document_size: result[:size]
    )

    result
  end

  def delete_main_policy_from_r2
    return unless main_policy_document_key.present?

    R2Service.delete(main_policy_document_key)
    update!(
      main_policy_document_key: nil,
      main_policy_document_filename: nil,
      main_policy_document_content_type: nil,
      main_policy_document_size: nil
    )
  end

  def main_policy_r2_url
    return nil unless main_policy_document_key.present?
    R2Service.public_url(main_policy_document_key)
  end

  def has_main_policy_r2?
    main_policy_document_key.present?
  end

  def has_main_policy_r2_document?
    has_main_policy_r2?
  end

  # Total document count method
  def total_documents_count
    count = 0
    count += 1 if has_main_policy_r2?
    count += uploaded_documents.count
    count += policy_documents_records.count
    count += life_insurance_documents.count
    count
  end

  def has_any_documents?
    total_documents_count > 0
  end

  def main_policy_r2_filename
    main_policy_document_filename
  end

  # Alias for compatibility with view expectations
  def main_policy_r2_document_url
    main_policy_r2_url
  end

  private

  def parse_amount_text(text)
    return 0 if text.blank?

    # Clean up the text - remove currency symbols and extra whitespace
    clean_text = text.to_s.strip.downcase.gsub(/[₹,\s]/, '')

    # Extract numeric part
    numeric_part = clean_text.match(/[\d.]+/).to_s.to_f
    return 0 if numeric_part == 0

    # Check for lakhs/lakh
    if clean_text.match(/(lakhs?|lac)/)
      return (numeric_part * 100000).to_i
    end

    # Check for crores/crore
    if clean_text.match(/(crores?|cr)/)
      return (numeric_part * 10000000).to_i
    end

    # If no unit specified, treat as absolute value
    return numeric_part.to_i
  end

  def calculate_totals
    if net_premium.present?
      # Calculate GST amounts
      first_year_gst = net_premium * (first_year_gst_percentage.to_f / 100.0)
      second_year_gst = net_premium * (second_year_gst_percentage.to_f / 100.0)
      third_year_gst = net_premium * (third_year_gst_percentage.to_f / 100.0)

      # Total premium calculation (for first year)
      self.total_premium = (net_premium + first_year_gst).round(2)

      # Commission calculations
      if main_agent_commission_percentage.present?
        self.commission_amount = (net_premium * (main_agent_commission_percentage.to_f / 100.0)).round(2)
      end

      if commission_amount.present? && tds_percentage.present?
        self.tds_amount = (commission_amount * (tds_percentage.to_f / 100.0)).round(2)
        self.after_tds_value = (commission_amount - tds_amount).round(2)
      end

      # Calculate new commission structure
      calculate_commission_structure
    end
  end

  def calculate_commission_structure
    return unless net_premium.present?

    # Set default company expenses percentage if not already set
    self.company_expenses_percentage ||= SystemSetting.company_expenses_percentage

    # Calculate main income based on main_agent_commission_percentage if provided, otherwise use default
    if main_agent_commission_percentage.present?
      self.main_income_percentage = main_agent_commission_percentage
    else
      self.main_income_percentage ||= 10.0
    end
    self.main_income_amount = (net_premium * (main_income_percentage / 100.0)).round(2)

    # Sub-agent commission (now Affiliate)
    self.sub_agent_commission_percentage ||= 2.0
    self.sub_agent_commission_amount = (net_premium * (sub_agent_commission_percentage / 100.0)).round(2)
    calculate_tds_for_sub_agent

    # Ambassador commission
    self.ambassador_commission_percentage ||= 2.0
    self.ambassador_commission_amount = (net_premium * (ambassador_commission_percentage / 100.0)).round(2)
    calculate_tds_for_ambassador

    # Distributor commission
    self.distributor_commission_percentage ||= 1.0
    self.distributor_commission_amount = (net_premium * (distributor_commission_percentage / 100.0)).round(2)
    calculate_tds_for_distributor

    # Investor commission
    self.investor_commission_percentage ||= 2.0
    self.investor_commission_amount = (net_premium * (investor_commission_percentage / 100.0)).round(2)
    calculate_tds_for_investor

    # Total distribution percentage
    self.total_distribution_percentage = (
      sub_agent_commission_percentage +
      ambassador_commission_percentage +
      distributor_commission_percentage +
      investor_commission_percentage
    ).round(2)

    # Profit calculation
    remaining_percentage = main_income_percentage - total_distribution_percentage
    self.profit_percentage = (remaining_percentage - company_expenses_percentage).round(2)
    self.profit_amount = (net_premium * (profit_percentage / 100.0)).round(2)
  end

  def calculate_tds_for_sub_agent
    if sub_agent_commission_amount.present? && sub_agent_tds_percentage.present?
      self.sub_agent_tds_amount = (sub_agent_commission_amount * (sub_agent_tds_percentage / 100.0)).round(2)
      self.sub_agent_after_tds_value = (sub_agent_commission_amount - sub_agent_tds_amount).round(2)
    else
      self.sub_agent_after_tds_value = sub_agent_commission_amount&.round(2)
    end
  end

  def calculate_tds_for_ambassador
    if ambassador_commission_amount.present? && ambassador_tds_percentage.present?
      self.ambassador_tds_amount = (ambassador_commission_amount * (ambassador_tds_percentage / 100.0)).round(2)
      self.ambassador_after_tds_value = (ambassador_commission_amount - ambassador_tds_amount).round(2)
    else
      self.ambassador_after_tds_value = ambassador_commission_amount&.round(2)
    end
  end

  def calculate_tds_for_distributor
    if distributor_commission_amount.present? && distributor_tds_percentage.present?
      self.distributor_tds_amount = (distributor_commission_amount * (distributor_tds_percentage / 100.0)).round(2)
      self.distributor_after_tds_value = (distributor_commission_amount - distributor_tds_amount).round(2)
    else
      self.distributor_after_tds_value = distributor_commission_amount&.round(2)
    end
  end

  def calculate_tds_for_investor
    if investor_commission_amount.present? && investor_tds_percentage.present?
      self.investor_tds_amount = (investor_commission_amount * (investor_tds_percentage / 100.0)).round(2)
      self.investor_after_tds_value = (investor_commission_amount - investor_tds_amount).round(2)
    else
      self.investor_after_tds_value = investor_commission_amount&.round(2)
    end
  end

  def set_policy_term_from_dates
    # Only auto-calculate policy term if it's completely blank/nil
    # Don't override if user has manually selected a value
    if policy_start_date.present? && policy_end_date.present? && policy_term.nil?
      years = (policy_end_date - policy_start_date) / 365.25
      self.policy_term = years.round
    end
  end

  def set_default_premium_payment_term
    # Set default premium payment term if not provided
    # Use policy_term as default if available, otherwise default to 10 years
    if premium_payment_term.blank?
      self.premium_payment_term = policy_term.present? ? policy_term : 10
    end
  end

  def agency_code_must_exist
    return if agency_code_id.blank?
    unless AgencyCode.exists?(agency_code_id)
      errors.add(:agency_code_id, "is invalid or no longer exists")
    end
  end

  def company_name_must_be_valid
    return if insurance_company_name.blank?
    # Skip validation for customer-added policies (they can input any company name)
    return if is_customer_added?
    # Skip validation for agent-added policies (they can input any company name)
    return if is_agent_added?

    exists = InsuranceCompany.where(name: insurance_company_name).exists?

    unless exists
      errors.add(:insurance_company_name, "must be a valid insurance company")
    end
  end

  def end_date_after_start_date
    return unless policy_start_date && policy_end_date

    if policy_end_date <= policy_start_date
      errors.add(:policy_end_date, "must be after policy start date")
    end
  end

  def set_notification_dates
    return unless policy_end_date.present? && (saved_change_to_policy_end_date? || notification_dates.blank?)

    notification_schedule = []

    # 1 month before expiry
    one_month_before = policy_end_date - 30.days
    notification_schedule << {
      type: 'renewal',
      title: 'Life Policy Renewal Reminder - 1 Month',
      message: "Your life policy (#{policy_number}) is due for renewal on #{policy_end_date.strftime('%d %b %Y')}. Please renew to continue your coverage.",
      date: one_month_before.to_s
    }

    # 15 days before expiry
    fifteen_days_before = policy_end_date - 15.days
    notification_schedule << {
      type: 'renewal',
      title: 'Life Policy Renewal Reminder - 15 Days',
      message: "Your life policy (#{policy_number}) expires in 15 days on #{policy_end_date.strftime('%d %b %Y')}. Please renew to avoid coverage gap.",
      date: fifteen_days_before.to_s
    }

    # 7 days before expiry
    seven_days_before = policy_end_date - 7.days
    notification_schedule << {
      type: 'renewal',
      title: 'Life Policy Renewal Reminder - 1 Week',
      message: "Your life policy (#{policy_number}) expires in 1 week on #{policy_end_date.strftime('%d %b %Y')}. Immediate action required.",
      date: seven_days_before.to_s
    }

    # 1 day before expiry
    one_day_before = policy_end_date - 1.day
    notification_schedule << {
      type: 'renewal',
      title: 'Life Policy Renewal Reminder - Final Notice',
      message: "Your life policy (#{policy_number}) expires tomorrow on #{policy_end_date.strftime('%d %b %Y')}. Renew now to avoid coverage gap.",
      date: one_day_before.to_s
    }

    # Only include future dates
    future_notifications = notification_schedule.select { |n| Date.parse(n[:date]) >= Date.current }

    update_column(:notification_dates, future_notifications.to_json) if future_notifications.any?
  end

  def create_commission_payouts
    # Commission payouts are now handled by StructuredPayoutService in create_structured_payout
    # This method is kept for backward compatibility but does nothing to avoid duplicates
    Rails.logger.info "Commission payouts handled by StructuredPayoutService for life insurance #{id}"
  end

  def create_lead_record
    return if lead_id.present? # Skip if lead already exists
    return if is_customer_added? # Skip auto-creation for customer-added policies

    LeadGeneratorService.create_lead_for_insurance(self)
  rescue StandardError => e
    Rails.logger.error "Failed to create lead for life insurance #{id}: #{e.message}"
  end

  # Inherit lead_id from customer if not already set
  def set_product_through_dr
    self.product_through_dr = true
  end

  def inherit_customer_lead_id
    return if lead_id.present? || customer.nil? || customer.lead_id.blank?

    # Check if customer's lead_id is already used by another life insurance policy
    if LifeInsurance.exists?(lead_id: customer.lead_id)
      # Generate a unique lead_id for this policy
      base_lead_id = customer.lead_id
      counter = 1

      loop do
        new_lead_id = "#{base_lead_id}-#{counter}"
        unless LifeInsurance.exists?(lead_id: new_lead_id)
          self.lead_id = new_lead_id
          break
        end
        counter += 1
        # Safety check to prevent infinite loop
        break if counter > 1000
      end
    else
      self.lead_id = customer.lead_id
    end
  end

  def create_structured_payout
    return unless net_premium.present? && net_premium > 0
    return unless drwise_policy? # Only create payouts for DrWise policies

    # Create structured payout with hierarchical commission structure
    StructuredPayoutService.create_for_policy(self, 'life')
  rescue StandardError => e
    Rails.logger.error "Failed to create structured payout for life insurance #{id}: #{e.message}"
  end

  def normalize_numeric_fields
    # Convert empty strings to nil for numeric fields to prevent validation errors
    self.policy_term = nil if policy_term.blank?
    self.net_premium = nil if net_premium.blank?
    self.total_premium = nil if total_premium.blank?
  end
end
