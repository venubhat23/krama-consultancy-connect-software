class PolicyDocument < ApplicationRecord
  # Validations
  validates :policy_type, presence: true
  validates :policy_id, presence: true
  validates :document_type, presence: true
  validates :title, presence: true

  validates :policy_type, inclusion: {
    in: ['health', 'life', 'motor', 'other', 'mutual_fund']
  }

  validates :document_type, inclusion: {
    in: ['Policy Document', 'Additional Document', 'Identity Proof', 'Medical Report', 'RC Book', 'Other']
  }

  # Scopes
  scope :for_policy, ->(policy_type, policy_id) { where(policy_type: policy_type, policy_id: policy_id) }
  scope :by_type, ->(document_type) { where(document_type: document_type) }

  # Instance methods
  def has_r2_document?
    r2_file_key.present? && r2_filename.present?
  end

  def document_name
    has_r2_document? ? r2_filename : "No file attached"
  end

  def document_size
    has_r2_document? ? number_to_human_size(r2_file_size || 0) : "0 KB"
  end

  def document_url
    return nil unless has_r2_document?
    R2Service.public_url(r2_file_key)
  end

  def public_document_url
    document_url
  end

  # Generate a download URL with proper filename
  def download_url
    return nil unless has_r2_document?
    base_url = document_url
    return base_url unless base_url.present?

    # Add content-disposition for proper download with filename
    "#{base_url}?response-content-disposition=attachment;filename=#{CGI.escape(r2_filename || 'document')}"
  end

  # Provide filename for compatibility
  def filename
    r2_filename || title || "document"
  end

  def upload_to_r2(file)
    return { error: 'No file provided' } unless file.present?

    begin
      # Validate file before upload
      validation_result = validate_file(file)
      return validation_result if validation_result[:error]

      # Upload to R2
      folder = "policy_documents/#{policy_type}"
      result = R2Service.upload(file, folder: folder)

      if result[:error]
        return { error: result[:error] }
      end

      # Update model with R2 data
      self.update_columns(
        r2_file_key: result[:key],
        r2_filename: result[:filename],
        r2_content_type: result[:content_type],
        r2_file_size: result[:size]
      )

      { success: true, url: result[:public_url] }
    rescue => e
      Rails.logger.error "PolicyDocument R2 Upload Error: #{e.message}"
      { error: e.message }
    end
  end

  def delete_from_r2
    return false unless has_r2_document?

    begin
      # Delete from R2
      R2Service.delete(r2_file_key)

      # Clear R2 fields
      self.update_columns(
        r2_file_key: nil,
        r2_filename: nil,
        r2_content_type: nil,
        r2_file_size: nil
      )

      true
    rescue => e
      Rails.logger.error "PolicyDocument R2 Delete Error: #{e.message}"
      false
    end
  end

  def policy_object
    case policy_type
    when 'health'
      HealthInsurance.find_by(id: policy_id)
    when 'life'
      LifeInsurance.find_by(id: policy_id)
    when 'motor'
      MotorInsurance.find_by(id: policy_id)
    when 'other'
      OtherInsurance.find_by(id: policy_id)
    when 'mutual_fund'
      MutualFund.find_by(id: policy_id)
    end
  end

  private

  def number_to_human_size(number)
    ActionController::Base.helpers.number_to_human_size(number)
  end

  def validate_file(file)
    # Check content type
    allowed_types = %w[image/jpeg image/jpg image/png application/pdf application/msword application/vnd.openxmlformats-officedocument.wordprocessingml.document]
    unless allowed_types.include?(file.content_type)
      return { error: 'File must be JPEG, PNG, PDF, or Word document' }
    end

    # Check file size (10MB = 10 * 1024 * 1024 bytes)
    if file.size > 10.megabytes
      return { error: 'File must be less than 10MB' }
    end

    { success: true }
  end
end
