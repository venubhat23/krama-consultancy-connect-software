class OtherInsurance < ApplicationRecord
  include ClearsAnalyticsCache
  belongs_to :policy, optional: true
  belongs_to :customer
  belongs_to :sub_agent, optional: true
  belongs_to :distributor, optional: true
  belongs_to :agency_code, optional: true
  has_many_attached :documents
  has_many_attached :policy_documents
  has_many_attached :additional_documents
  has_many :uploaded_documents, as: :documentable, class_name: 'Document', dependent: :destroy
  has_many :other_insurance_nominees, dependent: :destroy
  has_many :other_insurance_documents, dependent: :destroy  # R2 documents
  has_many :policy_documents_records, -> { where(policy_type: 'other') },
           class_name: 'PolicyDocument',
           foreign_key: 'policy_id',
           dependent: :destroy

  # Nested attributes
  accepts_nested_attributes_for :uploaded_documents, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :other_insurance_nominees, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :other_insurance_documents, allow_destroy: true, reject_if: :all_blank

  # Callbacks
  before_create :inherit_customer_lead_id
  before_create :set_product_through_dr
  after_create :create_commission_payouts
  after_create :create_lead_record
  after_commit :clear_dashboard_cache

  # Validations
  validates :customer_id, presence: { message: "Client name is required" }
  validates :policy_start_date, presence: true
  validates :policy_end_date, presence: true
  validates :policy_number, presence: true, uniqueness: true
  validates :insurance_company_name, presence: { message: "Insurance company name is required" }
  validates :insurance_type, presence: { message: "Insurance type is required" }
  validates :policy_type, presence: { message: "Policy type is required" }

  # Scopes
  scope :active, -> { where('policy_end_date >= ?', Date.current) }
  scope :expired, -> { where('policy_end_date < ?', Date.current) }
  scope :expiring_soon, -> { where(policy_end_date: Date.current..30.days.from_now) }

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

  # Renewal relationships
  belongs_to :original_policy, class_name: 'OtherInsurance', foreign_key: 'original_policy_id', optional: true
  has_one :renewal_policy, class_name: 'OtherInsurance', foreign_key: 'original_policy_id', dependent: :destroy

  # Renewal-related methods
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

  # Source tracking methods
  def is_customer_added?
    # Return false as default since the column might not exist yet
    respond_to?(:is_customer_added) ? read_attribute(:is_customer_added) : false
  end

  def is_agent_added?
    # Return false as default since the column might not exist yet
    respond_to?(:is_agent_added) ? read_attribute(:is_agent_added) : false
  end

  def is_admin_added?
    # Return false as default since the column might not exist yet
    respond_to?(:is_admin_added) ? read_attribute(:is_admin_added) : false
  end

  def policy_added_by_admin?
    # Return false as default since the column might not exist yet
    respond_to?(:policy_added_by_admin) ? read_attribute(:policy_added_by_admin) : false
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

  # Document handling methods
  def has_main_policy_r2_document?
    has_main_policy_r2?
  end

  def has_main_policy_r2?
    main_policy_document_key.present?
  end

  # Total document count method
  def total_documents_count
    count = 0
    count += 1 if has_main_policy_r2?
    count += documents.attached? ? documents.count : 0
    count += policy_documents.attached? ? policy_documents.count : 0
    count += additional_documents.attached? ? additional_documents.count : 0
    count += uploaded_documents.count
    count += other_insurance_documents.count
    count += policy_documents_records.count
    count
  end

  def has_any_documents?
    total_documents_count > 0
  end

  def main_policy_r2_url
    return nil unless main_policy_document_key.present?
    R2Service.public_url(main_policy_document_key) if defined?(R2Service)
  end

  def main_policy_r2_document_url
    main_policy_r2_url
  end

  def main_policy_document_filename
    read_attribute(:main_policy_document_filename)
  end

  def main_policy_document_size
    read_attribute(:main_policy_document_size)
  end

  def main_policy_document_content_type
    read_attribute(:main_policy_document_content_type)
  end

  def main_policy_document_key
    read_attribute(:main_policy_document_key)
  end

  # Customer association is now direct, not through policy

  def policy_number
    read_attribute(:policy_number) || "OTHER-#{id}"
  end

  def net_premium
    read_attribute(:net_premium) || total_premium
  end

  # R2 Direct Upload Methods for main policy document
  def upload_main_policy_to_r2(file)
    result = R2Service.upload(file, folder: "other_insurance/#{id}")

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
    count += uploaded_documents.count
    count += policy_documents_records.count
    count += other_insurance_documents.count
    count
  end

  def has_any_documents?
    total_documents_count > 0
  end

  private

  def clear_dashboard_cache
    Rails.cache.write("dashboard_cache_gen", SecureRandom.hex(4))
    Rails.cache.delete("dashboard_filter_independent_#{Date.current}_v3")
  rescue => e
    Rails.logger.warn "Failed to clear dashboard cache: #{e.message}"
  end

  def create_commission_payouts
    return unless drwise_policy? # Only create payouts for DrWise policies
    # Create commission payouts using StructuredPayoutService
    StructuredPayoutService.create_for_policy(self, 'other') if defined?(StructuredPayoutService)
    Rails.logger.info "Commission payouts handled by StructuredPayoutService for other insurance #{id}"
  rescue StandardError => e
    Rails.logger.error "Failed to create commission payouts for other insurance #{id}: #{e.message}"
  end

  def create_lead_record
    return if lead_id.present? # Skip if lead already exists
    return unless customer # Skip if no customer
    return if respond_to?(:is_customer_added?) && is_customer_added? # Skip auto-creation for customer-added policies

    LeadGeneratorService.create_lead_for_insurance(self) if defined?(LeadGeneratorService)
  rescue StandardError => e
    Rails.logger.error "Failed to create lead for other insurance #{id}: #{e.message}"
  end

  # Inherit lead_id from customer if not already set
  def set_product_through_dr
    self.product_through_dr = true
  end

  def inherit_customer_lead_id
    return if lead_id.present? || customer.nil?

    # Check if customer has a valid lead_id with an actual Lead record
    if customer.respond_to?(:lead_id) &&
       customer.lead_id.present? &&
       Lead.exists?(lead_id: customer.lead_id) &&
       !OtherInsurance.exists?(lead_id: customer.lead_id)

      self.lead_id = customer.lead_id
      Rails.logger.info "Inherited existing lead_id #{customer.lead_id} for other insurance"
    else
      # Generate a unique lead_id for this policy using the service
      if defined?(LeadIdGeneratorService)
        self.lead_id = LeadIdGeneratorService.generate_for_policy(customer, 'OtherInsurance')
        Rails.logger.info "Generated new lead_id #{self.lead_id} for other insurance"
      end
    end
  rescue StandardError => e
    Rails.logger.error "Failed to inherit lead_id for other insurance: #{e.message}"
  end

end
