require 'ostruct'

class Document < ApplicationRecord
  belongs_to :documentable, polymorphic: true

  # Virtual attribute for file uploads during form processing
  attr_accessor :document_file

  # Callbacks
  after_save :upload_document_file, if: :should_upload_file?

  # R2 File Storage - Direct upload to Cloudflare R2 (no ActiveStorage)
  # Uses columns: r2_file_key, r2_filename, r2_content_type, r2_file_size

  validates :document_type, presence: true
  # Note: file validation moved to custom method since we're not using ActiveStorage

  # File validation
  validate :acceptable_file_type
  validate :acceptable_file_size

  DOCUMENT_TYPES = [
    'aadhar', 'pan_card', 'driving_license', 'passport', 'voter_id',
    'birth_certificate', 'marriage_certificate', 'income_certificate',
    'salary_slip', 'bank_statement', 'gst_certificate', 'other',
    'travel_insurance_claim', 'property_insurance_claim', 'cyber_insurance_claim',
    'policy_document', 'claim_form', 'medical_certificate', 'financial_statement'
  ].freeze

  ALLOWED_FILE_TYPES = ['application/pdf', 'image/jpeg', 'image/jpg', 'image/png',
                        'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'].freeze

  validates :document_type, inclusion: { in: DOCUMENT_TYPES }

  scope :by_type, ->(type) { where(document_type: type) }
  scope :recent, -> { order(created_at: :desc) }

  # Instance methods for R2 file handling
  def file_name
    r2_filename.present? ? r2_filename : 'No file attached'
  end

  def file_size
    r2_file_size || 0
  end

  def file_type
    r2_content_type || 'Unknown'
  end

  def file_size_mb
    return 0 unless r2_file_size
    (r2_file_size.to_f / 1.megabyte).round(2)
  end

  def file_extension
    return '' unless r2_filename
    File.extname(r2_filename).downcase
  end

  def downloadable?
    has_file?
  end

  def has_file?
    r2_file_key.present?
  end

  def document_url
    return nil unless r2_file_key.present?
    "#{R2_CONFIG[:public_url]}/#{r2_file_key}"
  end

  def public_document_url
    document_url
  end

  # Generate a download URL with proper filename
  def download_url
    return nil unless r2_file_key.present?
    base_url = document_url
    return base_url unless base_url.present?

    # Add content-disposition for proper download with filename
    "#{base_url}?response-content-disposition=attachment;filename=#{CGI.escape(r2_filename || 'document')}"
  end

  def human_file_type
    case file_type
    when 'application/pdf'
      'PDF Document'
    when 'image/jpeg', 'image/jpg'
      'JPEG Image'
    when 'image/png'
      'PNG Image'
    when 'application/msword'
      'Word Document'
    when 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      'Word Document'
    else
      'Unknown'
    end
  end

  def human_document_type
    case document_type
    when 'aadhar'
      'Aadhaar Card'
    when 'pan_card'
      'PAN Card'
    when 'driving_license'
      'Driving License'
    when 'passport'
      'Passport'
    when 'voter_id'
      'Voter ID'
    when 'birth_certificate'
      'Birth Certificate'
    when 'marriage_certificate'
      'Marriage Certificate'
    when 'income_certificate'
      'Income Certificate'
    when 'salary_slip'
      'Salary Slip'
    when 'bank_statement'
      'Bank Statement'
    when 'gst_certificate'
      'GST Certificate'
    when 'travel_insurance_claim'
      'Travel Insurance Claim'
    when 'property_insurance_claim'
      'Property Insurance Claim'
    when 'cyber_insurance_claim'
      'Cyber Insurance Claim'
    when 'policy_document'
      'Policy Document'
    when 'claim_form'
      'Claim Form'
    when 'medical_certificate'
      'Medical Certificate'
    when 'financial_statement'
      'Financial Statement'
    when 'other'
      'Other Document'
    else
      document_type.humanize
    end
  end

  # Compatibility method for views expecting 'file' attribute (for R2 storage)
  def file
    return nil unless has_file?

    # Return an object that mimics ActiveStorage::Blob interface
    ::OpenStruct.new(
      filename: r2_filename,
      content_type: r2_content_type,
      byte_size: r2_file_size,
      key: r2_file_key,
      attached?: has_file?,
      signed_id: r2_file_key, # Use R2 key as signed_id equivalent
      present?: true,
      attached: true
    )
  end

  def file_icon
    case file_type
    when 'application/pdf'
      'file-earmark-pdf'
    when 'image/jpeg', 'image/jpg', 'image/png'
      'file-earmark-image'
    when 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      'file-earmark-word'
    when 'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      'file-earmark-excel'
    when 'text/plain'
      'file-earmark-text'
    when 'application/zip', 'application/x-zip-compressed'
      'file-earmark-zip'
    else
      case document_type
      when 'aadhar'
        'person-badge'
      when 'pan_card'
        'credit-card'
      when 'driving_license'
        'car-front'
      when 'passport'
        'airplane'
      when 'voter_id'
        'person-check'
      when 'birth_certificate', 'marriage_certificate'
        'award'
      when 'income_certificate', 'salary_slip'
        'receipt'
      when 'bank_statement'
        'bank'
      when 'gst_certificate'
        'building'
      when 'travel_insurance_claim', 'property_insurance_claim', 'cyber_insurance_claim'
        'shield-exclamation'
      when 'policy_document'
        'file-earmark-text'
      when 'claim_form'
        'clipboard-check'
      when 'medical_certificate'
        'heart-pulse'
      when 'financial_statement'
        'graph-up'
      else
        'file-earmark'
      end
    end
  end

  # R2 Upload method (to be used by controller)
  def upload_to_r2(file_param)
    return false unless file_param.present?

    # Validate file
    unless valid_file_type?(file_param.content_type)
      errors.add(:file, 'must be PDF, JPG, PNG, or DOC format')
      return false
    end

    if file_param.size > 10.megabytes
      errors.add(:file, 'must be less than 10MB')
      return false
    end

    begin
      # Use R2Service to upload
      folder = case documentable_type
               when 'Customer'
                 "customer_documents/#{documentable_id}"
               else
                 "documents/#{documentable_type.downcase}/#{documentable_id}"
               end

      result = R2Service.upload(file_param, folder: folder)

      if result[:key]
        # Update record with R2 file information
        update!(
          r2_file_key: result[:key],
          r2_filename: result[:filename],
          r2_content_type: result[:content_type],
          r2_file_size: result[:size]
        )
        return { success: true, key: result[:key], public_url: result[:public_url] }
      else
        errors.add(:file, "Upload failed: #{result[:error]}")
        return { error: result[:error] }
      end
    rescue => e
      errors.add(:file, "Upload failed: #{e.message}")
      return { error: e.message }
    end
  end

  # Delete from R2
  def delete_from_r2
    return true unless r2_file_key.present?

    begin
      result = R2Service.delete(r2_file_key)

      # Clear R2 fields regardless of deletion result
      update!(
        r2_file_key: nil,
        r2_filename: nil,
        r2_content_type: nil,
        r2_file_size: nil
      )

      return result
    rescue => e
      Rails.logger.error "Failed to delete file from R2: #{e.message}"
      return false
    end
  end

  private

  def number_to_human_size(number)
    ActionController::Base.helpers.number_to_human_size(number)
  end

  def valid_file_type?(content_type)
    ALLOWED_FILE_TYPES.include?(content_type)
  end

  def acceptable_file_type
    # This validation is now handled in upload_to_r2 method
    return true
  end

  def acceptable_file_size
    # This validation is now handled in upload_to_r2 method
    return true
  end

  # Callback methods for automatic file upload
  def should_upload_file?
    document_file.present? && r2_file_key.blank?
  end

  def upload_document_file
    return unless document_file.present?

    result = upload_to_r2(document_file)
    unless result[:success]
      Rails.logger.error "Failed to upload document file in callback: #{result[:error]}"
    end
  end
end