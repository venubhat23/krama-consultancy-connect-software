class Lead < ApplicationRecord
  include PgSearch::Model
  include ClearsAnalyticsCache

  validates :name, presence: true
  validates :contact_number, presence: true
  validate :validate_mobile_number_format
  validates :email,
    format: { with: URI::MailTo::EMAIL_REGEXP },
    allow_blank: true

  # Custom validations for uniqueness that skip branch out leads - DISABLED
  # validate :unique_contact_for_product_combination, unless: :is_branch_out?
  # validate :unique_email_for_product_combination, unless: :is_branch_out?
  validates :current_stage, presence: true, inclusion: { in: ['lead_generated', 'consultation_scheduled', 'one_on_one', 'follow_up', 'follow_up_successful', 'follow_up_unsuccessful', 'not_interested', 'converted', 're_follow_up', 'lead_closed'] }
  validates :lead_source, presence: true, inclusion: { in: ['online', 'offline', 'agent_referral', 'walk_in', 'tele_calling', 'campaign'] }
  validates :product_category, presence: true, inclusion: { in: ['insurance', 'investments', 'loans', 'taxation', 'travel', 'credit_card'] }
  validates :product_subcategory, presence: true
  validates :customer_type, presence: true, inclusion: { in: ['individual', 'corporate'] }
  validates :affiliate_id, presence: true, if: -> { !is_direct }
  validates :is_direct, inclusion: { in: [true, false] }

  # Individual Customer Required Fields
  validates :first_name, presence: true, format: { with: /\A[a-zA-Z\s]+\z/, message: "First name can only contain letters and spaces" }, if: :individual?
  validates :last_name, presence: true, format: { with: /\A[a-zA-Z\s]+\z/, message: "Last name can only contain letters and spaces" }, if: :individual?
  validates :middle_name, format: { with: /\A[a-zA-Z\s]*\z/, message: "Middle name can only contain letters and spaces" }, allow_blank: true, if: :individual?

  # Corporate Customer Required Fields
  validates :company_name, presence: true, if: :corporate?

  # Optional validations
  validates :gender, inclusion: { in: ['male', 'female', 'other'] }, allow_blank: true
  validates :marital_status, inclusion: { in: ['single', 'married', 'divorced', 'widowed'] }, allow_blank: true
  validates :pan_no, uniqueness: { message: "PAN number already exists", scope: :is_branch_out, conditions: -> { where(is_branch_out: [false, nil]) } }, format: { with: /\A[A-Z]{5}\d{4}[A-Z]\z/ }, allow_blank: true, unless: :is_branch_out?
  validates :gst_no, format: { with: /\A\d{2}[A-Z]{5}\d{4}[A-Z]\d[Z\d][A-Z\d]\z/ }, allow_blank: true
  validates :height, numericality: { greater_than_or_equal_to: 3.5, less_than_or_equal_to: 8.0 }, allow_blank: true
  validates :weight, numericality: { greater_than: 10, less_than_or_equal_to: 300 }, allow_blank: true
  validates :annual_income, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :business_job, inclusion: { in: ['salaried', 'self_employed', 'business', 'professional', 'student', 'retired', 'unemployed', 'other'] }, allow_blank: true

  belongs_to :converted_customer, class_name: 'Customer', optional: true
  belongs_to :created_policy, class_name: 'Policy', optional: true
  belongs_to :affiliate, class_name: 'SubAgent', optional: true
  belongs_to :ambassador, class_name: 'Distributor', optional: true
  belongs_to :parent_lead, class_name: 'Lead', optional: true
  has_many :branch_out_leads, class_name: 'Lead', foreign_key: 'parent_lead_id', dependent: :nullify
  has_many :uploaded_documents, as: :documentable, class_name: 'Document', dependent: :destroy

  before_create :generate_lead_id
  before_update :update_stage_timestamp, if: :current_stage_changed?
  before_validation :set_name_from_customer_details
  before_validation :set_initial_stage
  before_validation :clean_mobile_number

  enum :current_stage, {
    lead_generated: 'lead_generated',
    consultation_scheduled: 'consultation_scheduled',
    one_on_one: 'one_on_one',
    follow_up: 'follow_up',
    follow_up_successful: 'follow_up_successful',
    follow_up_unsuccessful: 'follow_up_unsuccessful',
    not_interested: 'not_interested',
    converted: 'converted',
    re_follow_up: 're_follow_up',
    lead_closed: 'lead_closed'
  }

  enum :lead_source, {
    online: 'online',
    offline: 'offline',
    agent_referral: 'agent_referral',
    walk_in: 'walk_in',
    tele_calling: 'tele_calling',
    campaign: 'campaign'
  }

  enum :product_category, {
    insurance: 'insurance',
    investments: 'investments',
    loans: 'loans',
    taxation: 'taxation',
    travel: 'travel',
    credit_card: 'credit_card'
  }

  enum :customer_type, {
    individual: 'individual',
    corporate: 'corporate'
  }

  # Define valid subcategories for each category
  PRODUCT_SUBCATEGORIES = {
    'insurance' => ['life', 'health', 'motor', 'general', 'travel', 'other'],
    'investments' => ['mutual_fund', 'fd', 'other'],
    'loans' => ['personal', 'home', 'mortgage', 'business'],
    'taxation' => ['itr', 'tax_planning'],
    'travel' => ['domestic', 'international'],
    'credit_card' => ['rewards', 'business', 'travel']
  }.freeze

  scope :by_stage, ->(stage) { where(current_stage: stage) }
  scope :by_source, ->(source) { where(lead_source: source) }
  scope :by_product_category, ->(category) { where(product_category: category) }
  scope :by_product_subcategory, ->(subcategory) { where(product_subcategory: subcategory) }
  scope :by_product, ->(product) { where(product_subcategory: product) }
  scope :recent, -> { order(created_date: :desc) }
  scope :pending_conversion, -> { where(current_stage: ['consultation_scheduled', 'one_on_one', 'follow_up', 're_follow_up']) }
  scope :converted_leads, -> { where(current_stage: 'converted') }
  scope :active_follow_up, -> { where(current_stage: ['follow_up', 're_follow_up']) }
  scope :direct_leads, -> { where(is_direct: true) }
  scope :referred_leads, -> { where(is_direct: false) }
  scope :by_affiliate, ->(affiliate_id) { where(affiliate_id: affiliate_id) }

  pg_search_scope :search_leads,
    against: [:name, :contact_number, :email, :referred_by, :product_category, :product_subcategory, :lead_id,
              :first_name, :middle_name, :last_name, :company_name],
    using: {
      tsearch: { prefix: true, any_word: true }
    }

  # Stage transition methods - Made more flexible to allow stage jumps
  def can_move_to_consultation?
    # Allow from lead_generated or any early stage
    lead_generated? || !cannot_change_stage?
  end

  def can_move_to_one_on_one?
    # Allow from consultation_scheduled or any non-final stage
    consultation_scheduled? || (!cannot_change_stage? && !in_follow_up_cycle?)
  end

  def can_move_to_follow_up?
    # Allow from one_on_one, consultation_scheduled, or any non-final stage
    one_on_one? || consultation_scheduled? || (!cannot_change_stage? && !in_follow_up_cycle?)
  end

  def can_mark_follow_up_successful?
    # Allow from follow_up, re_follow_up, or any stage that makes sense
    follow_up? || re_follow_up? || consultation_scheduled? || one_on_one? || (!cannot_change_stage?)
  end

  def can_mark_follow_up_unsuccessful?
    # Allow from follow_up, re_follow_up, or any stage that makes sense
    follow_up? || re_follow_up? || consultation_scheduled? || one_on_one? || (!cannot_change_stage?)
  end

  def can_mark_not_interested?
    # Allow from any stage except final stages
    !cannot_change_stage?
  end

  def can_re_follow_up?
    # Allow from follow_up_unsuccessful or any follow-up stage
    follow_up_unsuccessful? || follow_up? || (!cannot_change_stage?)
  end

  def can_convert_to_customer?
    # Allow conversion from any stage except already converted or closed
    !['converted', 'lead_closed'].include?(current_stage) && converted_customer_id.nil?
  end

  def can_create_policy?
    converted? && converted_customer_id.present?
  end

  def can_close_lead?
    not_interested? || converted? || (!cannot_change_stage?)
  end

  def cannot_change_stage?
    # Only prevent changes if lead is in truly final states
    lead_closed?
  end

  # Stage transition methods with validation
  def move_to_consultation_scheduled!
    return false unless can_move_to_consultation?
    update!(current_stage: 'consultation_scheduled', stage_updated_at: Time.current)
  end

  def move_to_one_on_one!
    return false unless can_move_to_one_on_one?
    update!(current_stage: 'one_on_one', stage_updated_at: Time.current)
  end

  def move_to_follow_up!
    return false unless can_move_to_follow_up?
    update!(current_stage: 'follow_up', stage_updated_at: Time.current)
  end

  def mark_follow_up_successful!
    return false unless can_mark_follow_up_successful?
    update!(current_stage: 'follow_up_successful', stage_updated_at: Time.current)
  end

  def mark_follow_up_unsuccessful!
    return false unless can_mark_follow_up_unsuccessful?
    update!(current_stage: 'follow_up_unsuccessful', stage_updated_at: Time.current)
  end

  def mark_not_interested!
    return false unless can_mark_not_interested?
    update!(current_stage: 'not_interested', stage_updated_at: Time.current)
  end

  def move_to_re_follow_up!
    return false unless can_re_follow_up?
    update!(current_stage: 're_follow_up', stage_updated_at: Time.current)
  end

  def convert_to_customer!(customer_id)
    return false unless can_convert_to_customer?
    update!(current_stage: 'converted', converted_customer_id: customer_id, stage_updated_at: Time.current)
  end

  def close_lead!
    return false unless can_close_lead?
    update!(current_stage: 'lead_closed', stage_updated_at: Time.current)
  end

  # Helper methods
  def converted?
    current_stage == 'converted'
  end

  def in_follow_up_cycle?
    ['follow_up', 'follow_up_successful', 'follow_up_unsuccessful', 're_follow_up'].include?(current_stage)
  end

  def can_settle_referral?
    current_stage == 'converted' && !transferred_amount && referral_amount > 0
  end

  def full_address
    [address, city, state].compact.join(', ')
  end

  def stage_badge_class
    case current_stage
    when 'lead_generated' then 'bg-secondary'
    when 'consultation_scheduled' then 'bg-info'
    when 'one_on_one' then 'bg-warning'
    when 'follow_up' then 'bg-primary'
    when 'follow_up_successful' then 'bg-success'
    when 'follow_up_unsuccessful' then 'bg-danger'
    when 'not_interested' then 'bg-dark'
    when 're_follow_up' then 'bg-warning'
    when 'converted' then 'bg-success'
    when 'lead_closed' then 'bg-secondary'
    else 'bg-secondary'
    end
  end

  def source_badge_class
    case lead_source
    when 'online', 'campaign' then 'bg-info'
    when 'agent_referral' then 'bg-success'
    when 'walk_in' then 'bg-secondary'
    when 'tele_calling' then 'bg-purple'
    when 'offline' then 'bg-warning'
    else 'bg-light'
    end
  end

  def product_badge_class
    case product_category
    when 'insurance' then 'bg-primary'
    when 'investments' then 'bg-success'
    when 'loans' then 'bg-warning'
    when 'taxation' then 'bg-info'
    when 'travel' then 'bg-purple'
    when 'credit_card' then 'bg-danger'
    else 'bg-secondary'
    end
  end

  def next_stage_options
    # Define base next stage options
    base_options = case current_stage
    when 'lead_generated' then ['consultation_scheduled']
    when 'consultation_scheduled' then ['one_on_one']
    when 'one_on_one' then ['follow_up']
    when 'follow_up' then ['follow_up_successful', 'follow_up_unsuccessful', 'not_interested']
    when 're_follow_up' then ['follow_up_successful', 'follow_up_unsuccessful', 'not_interested']
    when 'follow_up_successful' then ['converted']
    when 'follow_up_unsuccessful' then ['re_follow_up']
    when 'converted' then ['lead_closed']
    when 'not_interested' then ['lead_closed']
    else []
    end

    # Add 'converted' option to all stages that can convert (except final stages)
    if can_convert_to_customer? && !base_options.include?('converted')
      base_options + ['converted']
    else
      base_options
    end
  end

  def stage_display_name
    case current_stage
    when 'lead_generated' then '🟢 Lead Generated'
    when 'consultation_scheduled' then '📅 Consultation Scheduled'
    when 'one_on_one' then '🤝 One-on-One Discussion'
    when 'follow_up' then '🔁 Follow-Up'
    when 'follow_up_successful' then '✅ Successful'
    when 'follow_up_unsuccessful' then '❌ Not Successful'
    when 'not_interested' then '🚫 Not Interested'
    when 're_follow_up' then '🔄 Re-Follow Up'
    when 'converted' then '👤 Convert to Customer'
    when 'lead_closed' then '📁 Lead Close - Follow-Up Unsuccessful'
    else current_stage.humanize
    end
  end

  def product_subcategory_display
    case product_subcategory
    # Insurance subcategories
    when 'life' then 'Life Insurance'
    when 'health' then 'Health Insurance'
    when 'motor' then 'Motor Insurance'
    when 'general' then 'General Insurance'
    # Investment subcategories
    when 'mutual_fund' then 'Mutual Fund'
    when 'fd' then 'Fixed Deposit (FD)'
    # Loan subcategories
    when 'personal' then 'Personal Loan'
    when 'home' then 'Home Loan'
    when 'mortgage' then 'Mortgage Loan'
    when 'business' then 'Business Loan'
    # Taxation subcategories
    when 'itr' then 'ITR Filing'
    when 'tax_planning' then 'Tax Planning'
    # Travel subcategories
    when 'domestic' then 'Domestic Travel'
    when 'international' then 'International Travel'
    # Credit Card subcategories
    when 'rewards' then 'Rewards Card'
    # Default cases
    when 'other' then 'Other'
    else product_subcategory&.humanize || 'N/A'
    end
  end

  def can_advance?
    next_stage_options.any?
  end

  def can_go_back?
    return false if locked_stage?

    # Define which stages can go back and to where
    case current_stage
    when 'consultation_scheduled'
      true # can go back to lead_generated
    when 'one_on_one'
      true # can go back to consultation_scheduled
    when 'follow_up'
      true # can go back to one_on_one
    when 'follow_up_successful', 'follow_up_unsuccessful', 'not_interested'
      true # can go back to follow_up
    when 're_follow_up'
      true # can go back to follow_up_unsuccessful
    else
      false # converted, policy_created, lead_closed cannot go back
    end
  end

  def next_stage
    # Get the first available next stage option
    next_stage_options.first
  end

  def previous_stage
    # Define reverse stage mapping for going back
    case current_stage
    when 'consultation_scheduled'
      'lead_generated'
    when 'one_on_one'
      'consultation_scheduled'
    when 'follow_up'
      'one_on_one'
    when 'follow_up_successful', 'follow_up_unsuccessful', 'not_interested'
      'follow_up'
    when 're_follow_up'
      'follow_up_unsuccessful'
    else
      nil
    end
  end

  def locked_stage?
    # Once lead is closed or converted, don't allow going back to prevent data inconsistency
    ['lead_closed', 'converted'].include?(current_stage)
  end

  def stage_progress_percentage
    stages = ['lead_generated', 'consultation_scheduled', 'one_on_one', 'follow_up', 'converted', 'lead_closed']
    current_index = stages.index(current_stage) || 0
    ((current_index + 1).to_f / stages.length * 100).round
  end

  def available_stages_for_transition
    # Return only valid next stage transitions, not all possible stages
    next_stage_options
  end

  def stage_description
    case current_stage
    when 'lead_generated' then 'Initial lead entry into system'
    when 'consultation_scheduled' then 'Initial consultation scheduled'
    when 'one_on_one' then 'Detailed discussion on premium and policy benefits'
    when 'follow_up' then 'Following up with customer for interest confirmation'
    when 'follow_up_successful' then 'Customer confirmed interest'
    when 'follow_up_unsuccessful' then 'Customer not interested at this time'
    when 'not_interested' then 'Customer explicitly not interested'
    when 're_follow_up' then 'Additional follow-up attempt'
    when 'converted' then 'Lead converted to customer'
    when 'lead_closed' then 'Lead close - Follow-up unsuccessful'
    else 'Unknown stage'
    end
  end

  def display_name
    if individual?
      "#{first_name} #{middle_name} #{last_name}".strip.squeeze(' ')
    elsif corporate?
      company_name
    else
      name
    end
  end

  def individual?
    customer_type == 'individual'
  end

  def corporate?
    customer_type == 'corporate'
  end

  def full_name
    if individual?
      "#{first_name} #{middle_name} #{last_name}".strip.squeeze(' ')
    else
      company_name || name
    end
  end

  def product_display_name
    "#{product_category&.humanize} - #{product_subcategory&.humanize}"
  end

  def insurance_interest
    product_subcategory&.humanize
  end

  def referral_type
    is_direct ? 'Direct' : 'Referred'
  end

  def affiliate_name
    affiliate&.display_name || 'N/A'
  end

  def ambassador_name
    ambassador&.display_name || 'N/A'
  end

  def created_date=(value)
    if value.is_a?(String) && value.match(/^\d{2}\/\d{2}\/\d{4}$/)
      parts = value.split('/')
      day, month, year = parts[0].to_i, parts[1].to_i, parts[2].to_i
      super(Date.new(year, month, day))
    else
      super(value)
    end
  end

  def formatted_created_date
    created_date&.strftime('%d/%m/%Y')
  end

  # Check if this is a branch out lead
  def is_branch_out?
    is_branch_out == true
  end

  # Calculate age from birth_date
  def age
    return nil unless birth_date.present?

    today = Date.current
    age = today.year - birth_date.year
    age -= 1 if today < birth_date + age.years
    age
  end

  # Format height for display (convert decimal feet to feet.inches)
  def formatted_height
    return nil unless height.present?

    feet = height.floor
    inches = ((height - feet) * 12).round

    # Handle edge case where rounding gives 12 inches
    if inches == 12
      feet += 1
      inches = 0
    end

    "#{feet}.#{inches.to_s.rjust(2, '0')}"
  end

  # Custom validation for unique contact number and product combination
  def unique_contact_for_product_combination
    return if contact_number.blank? || product_category.blank? || product_subcategory.blank?

    existing_lead = Lead.where(
      contact_number: contact_number,
      product_category: product_category,
      product_subcategory: product_subcategory
    ).where.not(id: id).first

    # if existing_lead
    #   errors.add(:contact_number, "Contact number already exists for this product combination")
    # end
  end

  # Custom validation for unique email and product combination
  def unique_email_for_product_combination
    return if email.blank? || product_category.blank? || product_subcategory.blank?

    existing_lead = Lead.where(
      email: email,
      product_category: product_category,
      product_subcategory: product_subcategory
    ).where.not(id: id).first

    # Commented out to allow duplicate emails for product combinations
    # This allows lead stage conversion without validation errors
    # if existing_lead
    #   errors.add(:email, "Email already exists for this product combination")
    # end
  end

  private

  def set_initial_stage
    self.current_stage = 'lead_generated' if current_stage.blank?
  end

  def generate_lead_id
    return if lead_id.present? # Don't regenerate if already set

    # Try to generate based on customer information if available
    if can_generate_custom_lead_id?
      self.lead_id = generate_custom_lead_id
    else
      # Fallback to legacy format for incomplete data
      generate_fallback_lead_id
    end

    # Ensure uniqueness
    ensure_lead_id_uniqueness
  end

  def can_generate_custom_lead_id?
    contact_number.present? && (
      (individual? && first_name.present?) ||
      (corporate? && company_name.present?)
    )
  end

  def generate_custom_lead_id
    # Extract first 5 characters of customer name
    customer_name_part = if individual? && first_name.present?
      first_name.to_s.strip.upcase[0, 5].ljust(5, 'X')
    elsif corporate? && company_name.present?
      company_name.to_s.strip.upcase[0, 5].ljust(5, 'X')
    else
      'CUSXX'
    end

    # Use first 5 characters of PAN number if available, otherwise use 5 random numbers
    pan_or_random_part = if pan_no.present?
      pan_no.to_s.strip.upcase[0, 5].ljust(5, 'X')
    else
      rand(10000..99999).to_s
    end

    "CUSLEAD-#{customer_name_part}-#{pan_or_random_part}"
  end

  def generate_fallback_lead_id
    # Use PAN number if present, otherwise use mobile number without +91 and spaces
    if pan_no.present?
      self.lead_id = pan_no
    elsif contact_number.present?
      # Clean mobile number: remove +91, spaces, and other formatting
      clean_mobile = contact_number.to_s.gsub(/[\s\-\(\)\+]/, '').gsub(/^91/, '')
      self.lead_id = clean_mobile
    else
      # Random ID if neither PAN nor mobile is available
      self.lead_id = "LEAD-#{Date.current.strftime('%Y%m%d')}-#{rand(1000..9999)}"
    end
  end

  def ensure_lead_id_uniqueness
    return unless lead_id.present?

    if Lead.where(lead_id: lead_id).where.not(id: id).exists?
      # If duplicate exists, append suffix
      original_id = lead_id
      counter = 1
      loop do
        self.lead_id = "#{original_id}-#{counter.to_s.rjust(2, '0')}"
        break unless Lead.where(lead_id: lead_id).where.not(id: id).exists?
        counter += 1
        # Safety check
        break if counter > 999
      end
    end
  end

  def update_stage_timestamp
    self.stage_updated_at = Time.current
  end

  def set_name_from_customer_details
    if name.blank? || name == 'Placeholder'
      if individual? && first_name.present? && last_name.present?
        self.name = "#{first_name} #{middle_name} #{last_name}".strip.squeeze(' ')
      elsif corporate? && company_name.present?
        self.name = company_name
      else
        # Fallback for cases where customer type isn't set yet
        self.name = 'Lead' if name.blank? || name == 'Placeholder'
      end
    end
  end

  def clean_mobile_number
    return if contact_number.blank?

    # Remove all non-digit characters
    clean_number = contact_number.to_s.gsub(/\D/, '')

    # Only remove 91 prefix if:
    # 1. Number has exactly 12 digits AND starts with 91
    # 2. After removing 91, the remaining number starts with 6, 7, 8, or 9
    if clean_number.length == 12 && clean_number.start_with?('91')
      remaining_number = clean_number[2..-1]
      if remaining_number.match?(/\A[6789]/)
        clean_number = remaining_number
      end
    end

    # Store the clean number (could be any length, validation will check)
    self.contact_number = clean_number
  end

  def validate_mobile_number_format
    return if contact_number.blank?

    # After cleaning, validate the format
    unless contact_number.match?(/\A[6789]\d{9}\z/)
      errors.add(:contact_number, 'Mobile number must be 10 digits starting with 6, 7, 8, or 9')
    end
  end

end
