class Investor < ApplicationRecord
  include PgSearch::Model

  # Password authentication
  has_secure_password validations: false

  # Associations
  has_many :investor_documents, dependent: :destroy
  has_many :health_insurances, dependent: :nullify
  has_many :motor_insurances, dependent: :nullify
  # Note: other_insurances don't have investor_id column, so no direct association

  # R2 File Storage fields (direct upload to Cloudflare R2, no ActiveStorage)
  # Columns: main_document_key, main_document_filename, main_document_content_type, main_document_size

  # File upload validations (for direct R2 upload)
  validate :r2_main_document_validation

  # Nested attributes for documents
  accepts_nested_attributes_for :investor_documents, allow_destroy: true, reject_if: :all_blank

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :mobile, presence: true, uniqueness: true
  validates :mobile, format: {
    with: /\A[6789]\d{9}\z/,
    message: "must be a valid 10-digit mobile number starting with 6, 7, 8, or 9"
  }
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role_id, presence: true
  validates :username, presence: true, uniqueness: true
  validates :gender, inclusion: { in: ['Male', 'Female', 'Other'] }, allow_blank: true
  validates :account_type, inclusion: { in: ['Savings', 'Current', 'Salary'] }, allow_blank: true

  # Callbacks
  before_validation :format_mobile_number
  before_validation :set_default_role_id, on: :create
  before_validation :generate_username, on: :create
  before_create :set_default_password

  # Enums
  enum :status, { active: 0, inactive: 1 }

  # Search configuration
  pg_search_scope :search_by_name_mobile_email,
                  against: [:first_name, :last_name, :mobile, :email],
                  using: {
                    tsearch: { prefix: true }
                  }

  # Instance methods
  def full_name
    "#{first_name} #{middle_name} #{last_name}".strip
  end

  def display_name
    "#{first_name} #{last_name}"
  end

  def formatted_mobile
    return "N/A" if mobile.blank?

    # Extract 10-digit mobile number and add +91 prefix
    clean_mobile = mobile.to_s.gsub(/[^\d]/, '')
    ten_digit_mobile = nil

    if clean_mobile.start_with?('91') && clean_mobile.length == 12
      # 91XXXXXXXXXX format - extract 10-digit part
      digits_part = clean_mobile[2..-1]
      ten_digit_mobile = digits_part if digits_part.length == 10 && digits_part.match?(/\A[6789]\d{9}\z/)
    elsif clean_mobile.length == 10 && clean_mobile.match?(/\A[6789]\d{9}\z/)
      # XXXXXXXXXX format - valid 10 digit number
      ten_digit_mobile = clean_mobile
    elsif clean_mobile.length == 11 && clean_mobile.start_with?('0')
      # 0XXXXXXXXXX format - remove leading zero
      digits_part = clean_mobile[1..-1]
      ten_digit_mobile = digits_part if digits_part.length == 10 && digits_part.match?(/\A[6789]\d{9}\z/)
    end

    # Return formatted mobile with +91 prefix if we have valid 10-digit number
    if ten_digit_mobile
      "+91 #{ten_digit_mobile}"
    else
      # Any other format - return as is
      mobile
    end
  end

  def formatted_email
    email.presence || "N/A"
  end

  def mobile_for_form
    return "" if mobile.blank?

    # Extract just the 10-digit mobile number for form display
    clean_mobile = mobile.to_s.gsub(/[^\d]/, '')

    if clean_mobile.start_with?('91') && clean_mobile.length >= 12
      # 91XXXXXXXXXX format - extract 10-digit part
      clean_mobile[2, 10]
    elsif clean_mobile.length == 10 && clean_mobile.match?(/\A[6789]\d{9}\z/)
      # XXXXXXXXXX format - valid 10 digit number
      clean_mobile
    elsif clean_mobile.length == 11 && clean_mobile.start_with?('0')
      # 0XXXXXXXXXX format - remove leading zero
      clean_mobile[1, 10]
    else
      # Take first 10 digits if longer, or return as is if shorter
      clean_mobile.length > 10 ? clean_mobile[0, 10] : clean_mobile
    end
  end

  def main_document_url
    r2_document_url
  end

  def public_main_document_url
    r2_document_url
  end

  # R2 Direct Upload Methods
  def upload_to_r2(file)
    result = R2Service.upload(file, folder: "investors/#{id}")

    if result[:error]
      errors.add(:upload_main_document, "Upload failed: #{result[:error]}")
      return false
    end

    # Store R2 file information
    update!(
      main_document_key: result[:key],
      main_document_filename: result[:filename],
      main_document_content_type: result[:content_type],
      main_document_size: result[:size]
    )

    result
  end

  def delete_from_r2
    return unless main_document_key.present?

    R2Service.delete(main_document_key)
    update!(
      main_document_key: nil,
      main_document_filename: nil,
      main_document_content_type: nil,
      main_document_size: nil
    )
  end

  def r2_document_url
    return nil unless main_document_key.present?
    R2Service.public_url(main_document_key)
  end

  def has_r2_document?
    main_document_key.present?
  end

  private

  def format_mobile_number
    return if mobile.blank?

    # Remove all non-digit characters
    clean_mobile = mobile.to_s.gsub(/[^\d]/, '')

    # Handle different input formats - always extract 10-digit number
    if clean_mobile.start_with?('91') && clean_mobile.length == 12
      # 91XXXXXXXXXX format - extract 10-digit part
      digits_part = clean_mobile[2..-1]
      if digits_part.length == 10 && digits_part.match?(/\A[6789]\d{9}\z/)
        self.mobile = digits_part
      else
        # Invalid format, let validation handle it
        self.mobile = clean_mobile
      end
    elsif clean_mobile.length == 10 && clean_mobile.match?(/\A[6789]\d{9}\z/)
      # XXXXXXXXXX format - valid 10 digit number starting with 6, 7, 8, or 9
      self.mobile = clean_mobile
    elsif clean_mobile.length == 11 && clean_mobile.start_with?('0')
      # 0XXXXXXXXXX format - remove leading zero
      digits_part = clean_mobile[1..-1]
      if digits_part.length == 10 && digits_part.match?(/\A[6789]\d{9}\z/)
        self.mobile = digits_part
      else
        # Invalid format, let validation handle it
        self.mobile = clean_mobile
      end
    else
      # Any other format - let validation handle it
      self.mobile = clean_mobile
    end
  end

  def set_default_role_id
    self.role_id ||= 'investor'
  end

  def generate_username
    return if username.present?

    base_username = "#{first_name&.downcase}#{last_name&.downcase}".gsub(/[^a-z]/, '')
    base_username = base_username[0..10] # Limit to 10 characters

    # Add numbers if username already exists
    counter = 1
    potential_username = base_username

    while Investor.exists?(username: potential_username)
      potential_username = "#{base_username}#{counter}"
      counter += 1
    end

    self.username = potential_username
  end

  def set_default_password
    # Only set default password if no password is provided and no password option is manual
    if password.blank? && original_password.blank?
      default_password = "Ganesha@123"
      self.password = default_password
      self.original_password = default_password
    elsif password.present? && original_password.blank?
      # If password is provided, store it in original_password too
      self.original_password = password
    end
  end

  def r2_main_document_validation
    # This validation is handled during the upload process in the controller
    # File type and size checks are performed in the R2Service.upload method
    true
  end
end
