class Customer < ApplicationRecord
  include PgSearch::Model
  include ClearsAnalyticsCache

  # Callbacks
  before_validation :format_mobile_number

  # Associations
  has_many :family_members, dependent: :destroy
  has_many :policies, dependent: :destroy
  has_many :corporate_members, dependent: :destroy
  has_many :documents, class_name: 'CustomerDocument', dependent: :destroy
  has_many :uploaded_documents, as: :documentable, class_name: 'Document', dependent: :destroy
  has_one_attached :profile_image
  has_many_attached :profile_images
  belongs_to :affiliate, class_name: 'SubAgent', foreign_key: 'sub_agent_id', optional: true

  # Lead associations - all leads that have been converted to this customer
  has_many :converted_leads, class_name: 'Lead', foreign_key: 'converted_customer_id', dependent: :nullify

  # Insurance associations
  has_many :health_insurances, dependent: :destroy
  has_many :life_insurances, dependent: :destroy
  has_many :motor_insurances, dependent: :destroy
  has_many :other_insurances, dependent: :destroy

  # New product associations
  has_many :investments, dependent: :destroy
  has_many :loans, dependent: :destroy
  has_many :mutual_funds, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :helpdesk_tickets, dependent: :destroy
  # has_many :tax_services, dependent: :destroy # Temporarily commented out due to incomplete table structure
  # has_many :travel_packages, dependent: :destroy # Temporarily commented out due to incomplete table structure

  # Nested attributes
  accepts_nested_attributes_for :family_members, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :corporate_members, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :documents, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :uploaded_documents, allow_destroy: true, reject_if: :all_blank

  # Validations
  validates :customer_type, presence: true, inclusion: { in: ['individual', 'corporate'] }

  # Individual Customer Required Fields
  validates :first_name, presence: true, if: :individual?
  validates :last_name, presence: true, if: :individual?
  validates :mobile, presence: true, if: :individual?
  validates :mobile, uniqueness: true, allow_blank: true, if: :individual?
  validates :mobile, format: { with: /\A[6789]\d{9}\z/, message: "must be a valid 10-digit Indian mobile number starting with 6, 7, 8, or 9" }, if: :individual?
  validates :birth_date, presence: true, if: :individual?

  # Corporate Customer Required Fields
  validates :company_name, presence: true, if: :corporate?
  validates :mobile, presence: true, if: :corporate?
  validates :mobile, uniqueness: true, allow_blank: true, if: :corporate?
  validates :mobile, format: { with: /\A[6789]\d{9}\z/, message: "must be a valid 10-digit Indian mobile number starting with 6, 7, 8, or 9" }, if: :corporate?
  validates :gst_no, presence: true, if: :corporate?

  # Nominee Details (mandatory for individual customers only)
  validates :nominee_name, presence: true, if: :individual?
  validates :nominee_relation, presence: true, if: :individual?
  validates :nominee_date_of_birth, presence: true, if: :individual?
  validates :nominee_relation, inclusion: {
    in: ['father', 'mother', 'spouse', 'son', 'daughter', 'brother', 'sister', 'other'],
    message: "must be a valid relationship"
  }, if: :individual?

  # Validations
  validates :status, inclusion: { in: [true, false] }

  # Profile image validations
  validate :profile_image_validation

  # Set default values
  after_initialize :set_defaults
  before_create :generate_lead_id_if_missing

  def set_defaults
    self.status = true if has_attribute?(:status) && status.nil?
  end

  # Email validations - different rules for individual vs corporate
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, if: :corporate?
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true, if: :individual?

  # Optional validations
  validates :gender, inclusion: { in: ['male', 'female', 'other'] }, allow_blank: true
  validates :marital_status, inclusion: { in: ['single', 'married', 'divorced', 'widowed'] }, allow_blank: true
  validates :pan_no, format: { with: /\A[A-Z]{5}\d{4}[A-Z]\z/ }, allow_blank: true
  validates :gst_no, format: { with: /\A\d{2}[A-Z]{5}\d{4}[A-Z]\d[Z\d][A-Z\d]\z/ }, allow_blank: true

  # Enums
  enum :customer_type, { individual: 'individual', corporate: 'corporate' }

  # Scopes
  scope :active, -> { where(status: true, deactivated: false) }
  scope :inactive, -> { where(status: false) }
  scope :deactivated, -> { where(deactivated: true) }
  scope :not_deactivated, -> { where(deactivated: false) }
  scope :individuals, -> { where(customer_type: 'individual') }
  scope :corporates, -> { where(customer_type: 'corporate') }

  # Callbacks
  before_validation :normalize_blank_values
  before_save :calculate_age
  after_update :handle_profile_images

  # Search
  pg_search_scope :search_customers,
    against: [:first_name, :last_name, :company_name, :email, :mobile, :pan_no, :lead_id],
    using: {
      tsearch: { prefix: true, any_word: true }
    }

  scope :partial_search, ->(term) {
    pattern = "%#{term}%"
    where(
      "first_name ILIKE :p OR last_name ILIKE :p OR company_name ILIKE :p " \
      "OR email ILIKE :p OR mobile ILIKE :p OR pan_number ILIKE :p " \
      "OR lead_id ILIKE :p OR CONCAT(first_name, ' ', last_name) ILIKE :p",
      p: pattern
    )
  }

  # Instance methods
  def full_name
    if individual?
      [first_name, middle_name, last_name].compact.join(' ').strip
    else
      company_name
    end
  end

  def display_name
    individual? ? full_name : company_name
  end

  def active?
    status && !deactivated
  end

  def deactivated?
    deactivated == true
  end

  def deactivate!
    update(deactivated: true)
  end

  def activate!
    update(deactivated: false)
  end

  def individual?
    customer_type == 'individual'
  end

  def corporate?
    customer_type == 'corporate'
  end

  def initials
    if individual?
      # For individual customers, use first and last name
      names = [first_name, last_name].compact.map(&:strip).reject(&:blank?)
      names.map { |name| name[0].upcase }.join('')
    else
      # For corporate customers, use company name
      return 'C' if company_name.blank?

      # Get first letters of company name words
      words = company_name.strip.split(/\s+/).reject(&:blank?)
      if words.length >= 2
        words.first(2).map { |word| word[0].upcase }.join('')
      else
        company_name.strip[0].upcase
      end
    end
  rescue
    # Fallback in case of any error
    individual? ? 'U' : 'C'
  end

  # Image helper methods
  def profile_image_url
    if profile_image.attached?
      begin
        # Try to generate full URL first
        Rails.application.routes.url_helpers.rails_blob_url(profile_image, only_path: false)
      rescue ArgumentError, ActionController::RoutingError => e
        # If host is not configured or other routing error, fall back to path only
        Rails.logger.warn "Host not configured for URL generation, using path only: #{e.message}"
        Rails.application.routes.url_helpers.rails_blob_path(profile_image)
      end
    else
      nil
    end
  rescue => e
    Rails.logger.error "Error generating profile image URL for customer #{id}: #{e.message}"
    nil
  end

  def has_profile_image?
    profile_image.attached? && profile_image.blob.present?
  rescue => e
    Rails.logger.error "Error checking profile image for customer #{id}: #{e.message}"
    false
  end

  def safe_profile_image_display
    return nil unless has_profile_image?

    url = profile_image_url
    return nil if url.blank?

    {
      url: url,
      public_url: public_profile_image_url,
      filename: profile_image.filename.to_s,
      size: profile_image.byte_size,
      content_type: profile_image.content_type
    }
  rescue => e
    Rails.logger.error "Error generating safe profile image display for customer #{id}: #{e.message}"
    nil
  end

  def public_profile_image_url
    if profile_image.attached?
      begin
        # Generate a direct public URL for downloading
        if Rails.env.development?
          # For development, use localhost
          host = Rails.application.config.hosts.first || 'localhost:3000'
          "http://#{host}#{Rails.application.routes.url_helpers.rails_blob_path(profile_image)}"
        else
          # For production, use the configured host
          Rails.application.routes.url_helpers.rails_blob_url(profile_image, only_path: false)
        end
      rescue => e
        Rails.logger.warn "Could not generate public URL: #{e.message}"
        profile_image_url
      end
    else
      nil
    end
  rescue => e
    Rails.logger.error "Error generating public profile image URL for customer #{id}: #{e.message}"
    nil
  end


  # R2 Profile Image methods
  def r2_profile_image
    if documents.loaded?
      documents.find { |d| d.document_type == 'Profile Image' }
    else
      documents.where(document_type: 'Profile Image').first
    end
  end

  def has_r2_profile_image?
    r2_profile_image&.has_file?
  end

  def r2_profile_image_url
    r2_profile_image&.document_url
  end

  # Get profile image URL (prioritize R2, fallback to ActiveStorage)
  def profile_image_display_url
    if has_r2_profile_image?
      r2_profile_image_url
    elsif profile_image.attached?
      profile_image_url
    else
      nil
    end
  end

  # Update the API mobile settings controller to use R2 profile image
  def api_profile_image_url
    profile_image_display_url
  end

  # Cache busting callback
  after_update :bust_cache

  def calculate_age
    if birth_date.present?
      today = Date.current
      birth = birth_date

      # Calculate years
      years = today.year - birth.year

      # Calculate if birthday hasn't occurred this year yet
      if today.month < birth.month || (today.month == birth.month && today.day < birth.day)
        years -= 1
      end

      # Store numeric age for compatibility
      self.age = years
    end
  end

  def formatted_age
    if birth_date.present?
      today = Date.current
      birth = birth_date

      # Calculate years
      years = today.year - birth.year

      # Calculate if birthday hasn't occurred this year yet
      if today.month < birth.month || (today.month == birth.month && today.day < birth.day)
        years -= 1
      end

      # Calculate the last birthday and days
      if years == 0
        # If less than a year old, calculate days from birth
        days = (today - birth).to_i
        "#{days} days"
      else
        # Calculate days since last birthday
        last_birthday = Date.new(today.year, birth.month, birth.day)
        if last_birthday > today
          last_birthday = Date.new(today.year - 1, birth.month, birth.day)
        end

        days = (today - last_birthday).to_i

        # Format the age string
        if days == 0
          "#{years} years"
        else
          "#{years} years, #{days} days"
        end
      end
    else
      ""
    end
  end

  private

  def format_mobile_number
    return if mobile.blank?

    # Remove all non-digit characters
    clean_mobile = mobile.to_s.gsub(/\D/, '')

    # Handle different input formats
    if clean_mobile.length == 13 && clean_mobile.start_with?('91')
      # Remove country code +91 (91XXXXXXXXXX)
      self.mobile = clean_mobile[2..-1]
    elsif clean_mobile.length == 12 && clean_mobile.start_with?('91')
      # Remove country code 91 (91XXXXXXXXXX)
      self.mobile = clean_mobile[2..-1]
    elsif clean_mobile.length == 11 && clean_mobile.start_with?('0')
      # Remove leading zero (0XXXXXXXXXX)
      self.mobile = clean_mobile[1..-1]
    elsif clean_mobile.length == 11 && clean_mobile[0] != '0'
      # Remove the first digit if it's not 0 and length is 11 (XXXXXXXXXXX)
      # This handles cases like 98989898989 -> 8989898989
      self.mobile = clean_mobile[1..-1]
    elsif clean_mobile.length == 10
      # Already 10 digits, keep as is
      self.mobile = clean_mobile
    else
      # Invalid length, keep original for validation to catch
      self.mobile = clean_mobile
    end
  end

  def bust_cache
    Rails.cache.delete("customer_#{id}_full_name")
    Rails.cache.delete("customer_#{id}_display_name")
  end

  def normalize_blank_values
    # Convert empty strings to nil to prevent uniqueness validation issues
    self.mobile = nil if mobile.blank?
    self.email = nil if email.blank?
    self.pan_no = nil if pan_no.blank?
    self.gst_no = nil if gst_no.blank?
  end

  # Generate lead_id if not already present (for direct customer creation)
  def generate_lead_id_if_missing
    return if lead_id.present?

    loop do
      self.lead_id = "CUST-#{Date.current.strftime('%Y%m%d')}-#{SecureRandom.alphanumeric(6).upcase}"
      break unless Customer.exists?(lead_id: self.lead_id) || Lead.exists?(lead_id: self.lead_id)
    end
  end

  # Handle multiple profile images by setting the first as primary
  def handle_profile_images
    return unless profile_images.attached? && profile_images.any?

    # If no primary profile image is set and we have profile_images, use the first one
    if !profile_image.attached? && profile_images.first
      profile_image.attach(profile_images.first.blob)
    end
  rescue => e
    Rails.logger.error "Error handling profile images for customer #{id}: #{e.message}"
  end

  # Profile image validation
  def profile_image_validation
    return unless profile_image.attached?

    # Validate file size (max 5MB)
    if profile_image.byte_size > 5.megabytes
      errors.add(:profile_image, 'is too large (should be less than 5MB)')
    end

    # Validate file type
    unless profile_image.content_type.in?(['image/jpeg', 'image/png', 'image/gif', 'image/webp'])
      errors.add(:profile_image, 'must be a JPEG, PNG, GIF, or WebP image')
    end

    # Validate multiple profile images if present
    if profile_images.attached?
      profile_images.each_with_index do |image, index|
        if image.byte_size > 5.megabytes
          errors.add(:profile_images, "image #{index + 1} is too large (should be less than 5MB)")
        end

        unless image.content_type.in?(['image/jpeg', 'image/png', 'image/gif', 'image/webp'])
          errors.add(:profile_images, "image #{index + 1} must be a JPEG, PNG, GIF, or WebP image")
        end
      end
    end
  rescue => e
    Rails.logger.error "Error validating profile image for customer #{id || 'new'}: #{e.message}"
    errors.add(:profile_image, 'validation failed due to an error')
  end

end
