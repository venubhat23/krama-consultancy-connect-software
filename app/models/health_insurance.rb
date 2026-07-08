class HealthInsurance < ApplicationRecord
  include PgSearch::Model
  include InsuranceCompanyConstants
  include DashboardOptimizable
  include ClearsAnalyticsCache

  # Associations
  belongs_to :customer, counter_cache: :policies_count
  belongs_to :sub_agent, class_name: 'SubAgent', optional: true
  belongs_to :distributor, optional: true
  belongs_to :investor, optional: true
  belongs_to :agency_code, optional: true
  belongs_to :broker, optional: true
  has_many :health_insurance_members, dependent: :destroy
  has_many :health_insurance_nominees, dependent: :destroy
  has_many :health_insurance_documents, dependent: :destroy
  has_many_attached :documents
  has_many_attached :policy_documents
  has_many :uploaded_documents, as: :documentable, class_name: 'Document', dependent: :destroy
  has_many :policy_documents_records, -> { where(policy_type: 'health') },
           class_name: 'PolicyDocument',
           foreign_key: 'policy_id',
           dependent: :destroy

  # Renewal relationships
  belongs_to :original_policy, class_name: 'HealthInsurance', foreign_key: 'original_policy_id', optional: true
  has_one :renewal_policy, class_name: 'HealthInsurance', foreign_key: 'original_policy_id', dependent: :destroy

  # Nested attributes
  accepts_nested_attributes_for :health_insurance_members, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :health_insurance_nominees, allow_destroy: true, reject_if: proc { |a| a['id'].blank? && a['nominee_name'].blank? }
  accepts_nested_attributes_for :health_insurance_documents, allow_destroy: true, reject_if: proc { |attrs| attrs['id'].blank? && attrs['r2_file_key'].blank? }
  accepts_nested_attributes_for :uploaded_documents, allow_destroy: true, reject_if: :all_blank

  # Virtual attributes
  attr_accessor :main_policy_document, :sum_insured_text, :company_expenses_amount,
                :main_policy_document_key, :main_policy_document_filename,
                :main_policy_document_content_type, :main_policy_document_size

  # Validations
  validates :policy_holder, presence: true
  validates :insurance_company_name, presence: true
  validates :policy_type, presence: true, inclusion: { in: ['New', 'Renewal', 'Porting', 'Migration'] }
  validates :insurance_type, presence: true, inclusion: { in: ['Individual', 'Family Floater', 'Group'] }
  validates :policy_booking_date, presence: true
  validates :policy_start_date, presence: true
  validates :policy_end_date, presence: true
  validates :payment_mode, presence: true
  validates :sum_insured, presence: true, numericality: { greater_than: 0 }
  validates :net_premium, presence: true, numericality: { greater_than: 0 }
  validates :gst_percentage, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :total_premium, presence: true, numericality: { greater_than: 0 }

  # Nominee validations (now optional since we use separate nominee model)
  # validates :nominee_name, presence: true
  # validates :nominee_relation, presence: true, inclusion: {
  #   in: ['father', 'mother', 'spouse', 'son', 'daughter', 'brother', 'sister', 'other'],
  #   message: "must be a valid relationship"
  # }
  # validates :nominee_dob, presence: true

  # Custom validation
  # validate :company_name_must_be_valid

  # Enums for dropdowns
  POLICY_TYPES = ['New', 'Renewal', 'Porting'].freeze
  INSURANCE_TYPES = ['Individual', 'Family Floater', 'Group'].freeze
  PAYMENT_MODES = ['Yearly', 'Half Yearly', 'Quarterly', 'Monthly', 'Single'].freeze
  CLAIM_PROCESSES = ['Inhouse', 'TPA'].freeze

  # Scopes
  scope :active, -> { where('policy_end_date >= ?', Date.current) }
  scope :expired, -> { where('policy_end_date < ?', Date.current) }
  scope :expiring_soon, -> { where(policy_end_date: Date.current..30.days.from_now) }

  # Search
  pg_search_scope :search_health_policies,
    against: [:policy_number, :plan_name, :insurance_company_name],
    associated_against: {
      customer: [:first_name, :last_name, :company_name]
    },
    using: {
      tsearch: { prefix: true, any_word: true }
    }

  # Callbacks
  before_save :calculate_totals
  before_save :calculate_commission_structure
  before_validation :set_policy_term
  after_save :set_notification_dates
  before_create :inherit_customer_lead_id
  before_create :set_product_through_dr
  after_create :create_commission_payouts
  after_create :create_lead_record

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

  def policy_holder_options
    options = [['Self', 'Self']]
    if customer&.family_members&.any?
      customer.family_members.each do |member|
        options << [member.full_name, member.id.to_s]
      end
    end
    options
  end

  def affiliate_name
    sub_agent ? sub_agent.display_name : 'Self'
  end

  def sum_insured_display_text
    return sum_insured_text if sum_insured_text.present?
    return '' unless sum_insured.present?

    # Convert numeric sum_insured to text format
    amount = sum_insured.to_f
    if amount >= 10_000_000 # 1 crore
      crores = amount / 10_000_000
      if crores == crores.to_i
        "#{crores.to_i} crore#{crores > 1 ? 's' : ''}"
      else
        "#{crores} crore#{crores > 1 ? 's' : ''}"
      end
    elsif amount >= 100_000 # 1 lakh
      lakhs = amount / 100_000
      if lakhs == lakhs.to_i
        "#{lakhs.to_i} lakh#{lakhs > 1 ? 's' : ''}"
      else
        "#{lakhs} lakh#{lakhs > 1 ? 's' : ''}"
      end
    else
      amount.to_i.to_s
    end
  end

  def is_renewal?
    policy_type == 'Renewal' || original_policy_id.present?
  end

  def has_been_renewed?
    (self.class.column_names.include?('is_renewed') && is_renewed == true) || renewal_policy.present?
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

  # DrWise vs Non-DrWise classification methods
  def drwise_policy?
    is_admin_added == true && is_customer_added == false && is_agent_added == false
  end

  def non_drwise_policy?
    (is_customer_added == true && is_admin_added == false && is_agent_added == false) ||
    (is_agent_added == true && is_customer_added == false && is_admin_added == false)
  end

  def policy_classification
    if drwise_policy?
      'DrWise'
    elsif non_drwise_policy?
      'Non-DrWise'
    else
      'Unclassified'
    end
  end

  def notifications_due_today
    return [] unless notification_dates.present?

    notification_list = JSON.parse(notification_dates)
    today = Date.current.to_s

    notification_list.select { |notification| notification['date'] == today }
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
          insurance_type: 'health'
        }
      end
    end

    notifications
  end

  # R2 Document Methods for Policy Document Manager
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

  def main_policy_r2_filename
    main_policy_document_filename
  end

  # Alias for compatibility with view expectations
  def main_policy_r2_document_url
    main_policy_r2_url
  end

  # Total document count method
  def total_documents_count
    count = 0
    count += 1 if has_main_policy_r2?
    count += documents.attached? ? documents.count : 0
    count += policy_documents.attached? ? policy_documents.count : 0
    count += uploaded_documents.count
    count += policy_documents_records.count
    count += health_insurance_documents.count if respond_to?(:health_insurance_documents)
    count
  end

  def has_any_documents?
    total_documents_count > 0
  end

  private

  def calculate_totals
    if net_premium.present? && gst_percentage.present?
      gst_amount = net_premium * (gst_percentage / 100.0)
      self.total_premium = (net_premium + gst_amount).round(2)
    end

    if net_premium.present? && main_agent_commission_percentage.present?
      self.commission_amount = (net_premium * (main_agent_commission_percentage / 100.0)).round(2)
    end

    if commission_amount.present? && tds_percentage.present?
      self.tds_amount = (commission_amount * (tds_percentage / 100.0)).round(2)
      self.after_tds_value = (commission_amount - tds_amount).round(2)
    end

    # Calculate commission structure for all roles
    calculate_commission_structure if net_premium.present?
  end

  def set_policy_term
    if policy_start_date.present? && policy_end_date.present?
      years = (policy_end_date - policy_start_date) / 365.25
      self.policy_term = years.round
    end
  end

  def company_name_must_be_valid
    return if insurance_company_name.blank?
    # Skip validation for customer-added policies (they can input any company name)
    return if is_customer_added?

    unless self.class.insurance_company_names.include?(insurance_company_name)
      errors.add(:insurance_company_name, "must be a valid insurance company")
    end
  end

  def set_notification_dates
    return unless policy_end_date.present? && (saved_change_to_policy_end_date? || notification_dates.blank?)

    notification_schedule = []

    # 1 month before expiry
    one_month_before = policy_end_date - 30.days
    notification_schedule << {
      type: 'renewal',
      title: 'Policy Renewal Reminder - 1 Month',
      message: "Your health policy (#{policy_number}) is due for renewal on #{policy_end_date.strftime('%d %b %Y')}. Please renew to continue your coverage.",
      date: one_month_before.to_s
    }

    # 15 days before expiry
    fifteen_days_before = policy_end_date - 15.days
    notification_schedule << {
      type: 'renewal',
      title: 'Policy Renewal Reminder - 15 Days',
      message: "Your health policy (#{policy_number}) expires in 15 days on #{policy_end_date.strftime('%d %b %Y')}. Please renew to avoid coverage gap.",
      date: fifteen_days_before.to_s
    }

    # 7 days before expiry
    seven_days_before = policy_end_date - 7.days
    notification_schedule << {
      type: 'renewal',
      title: 'Policy Renewal Reminder - 1 Week',
      message: "Your health policy (#{policy_number}) expires in 1 week on #{policy_end_date.strftime('%d %b %Y')}. Immediate action required.",
      date: seven_days_before.to_s
    }

    # 1 day before expiry
    one_day_before = policy_end_date - 1.day
    notification_schedule << {
      type: 'renewal',
      title: 'Policy Renewal Reminder - Final Notice',
      message: "Your health policy (#{policy_number}) expires tomorrow on #{policy_end_date.strftime('%d %b %Y')}. Renew now to avoid coverage gap.",
      date: one_day_before.to_s
    }

    # Only include future dates
    future_notifications = notification_schedule.select { |n| Date.parse(n[:date]) >= Date.current }

    update_column(:notification_dates, future_notifications.to_json) if future_notifications.any?
  end

  def create_commission_payouts
    return unless drwise_policy? # Only create payouts for DrWise policies
    # Create commission payouts using StructuredPayoutService
    StructuredPayoutService.create_for_policy(self, 'health')
    Rails.logger.info "Commission payouts handled by StructuredPayoutService for health insurance #{id}"
  end

  def create_lead_record
    return if lead_id.present? # Skip if lead already exists
    return if is_customer_added? # Skip auto-creation for customer-added policies

    LeadGeneratorService.create_lead_for_insurance(self)
  rescue StandardError => e
    Rails.logger.error "Failed to create lead for health insurance #{id}: #{e.message}"
  end

  # Inherit lead_id from customer if not already set
  def set_product_through_dr
    self.product_through_dr = true
  end

  def inherit_customer_lead_id
    return if lead_id.present? || customer.nil?

    # Check if customer's lead_id is already used in health insurance
    if customer.lead_id.present? && !HealthInsurance.exists?(lead_id: customer.lead_id)
      self.lead_id = customer.lead_id
    else
      # Generate a unique lead_id for this policy using the service
      self.lead_id = LeadIdGeneratorService.generate_for_policy(customer, 'health')
    end
  end

  private

  def calculate_commission_structure
    return unless net_premium.present?

    # Set default company expenses percentage if not already set
    self.company_expenses_percentage ||= 2.0

    # Main income calculation (10% default)
    main_income_percentage = 10.0

    # Sub-agent commission (now Affiliate)
    self.sub_agent_commission_percentage ||= 2.0
    self.sub_agent_commission_amount = (net_premium * (sub_agent_commission_percentage / 100.0)).round(2)
    calculate_tds_for_sub_agent

    # Ambassador commission
    self.ambassador_commission_percentage ||= 2.0
    self.ambassador_commission_amount = (net_premium * (ambassador_commission_percentage / 100.0)).round(2)
    calculate_tds_for_ambassador

    # Investor commission
    self.investor_commission_percentage ||= 2.0
    self.investor_commission_amount = (net_premium * (investor_commission_percentage / 100.0)).round(2)
    calculate_tds_for_investor

    # Total distribution percentage
    self.total_distribution_percentage = (
      sub_agent_commission_percentage +
      ambassador_commission_percentage +
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

  def calculate_tds_for_investor
    if investor_commission_amount.present? && investor_tds_percentage.present?
      self.investor_tds_amount = (investor_commission_amount * (investor_tds_percentage / 100.0)).round(2)
      self.investor_after_tds_value = (investor_commission_amount - investor_tds_amount).round(2)
    else
      self.investor_after_tds_value = investor_commission_amount&.round(2)
    end
  end

  public

  # R2 main policy document upload method
  def upload_main_policy_to_r2(file)
    return { error: 'No file provided' } unless file.present?

    begin
      result = R2Service.upload(file, folder: "health_insurance/#{id}/main_policy")

      if result && result[:key] && !result[:error]
        update_columns(
          main_policy_document_key: result[:key],
          main_policy_document_filename: result[:filename],
          main_policy_document_content_type: result[:content_type],
          main_policy_document_size: result[:size]
        )
        Rails.logger.info "Main policy document uploaded to R2 for health insurance #{id}: #{result[:key]}"
        return result
      else
        error_msg = result[:error] || "Upload failed"
        Rails.logger.error "Failed to upload main policy document to R2 for health insurance #{id}: #{error_msg}"
        return { error: error_msg }
      end
    rescue => e
      Rails.logger.error "Error uploading main policy document to R2 for health insurance #{id}: #{e.message}"
      return { error: e.message }
    end
  end
end
