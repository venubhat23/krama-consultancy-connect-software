class SubAgentDocument < ApplicationRecord
  # Associations
  belongs_to :sub_agent
  has_one_attached :document_file

  # Validations
  validates :document_type, presence: true
  validates :document_type, inclusion: {
    in: ['Aadhaar Card', 'Pancard', 'Driving License', 'Mediclaim', 'RC Book', 'Profile Image', 'Other File']
  }

  # Custom validation for file presence (either ActiveStorage or R2)
  validate :file_presence
  validate :validate_file_size

  # R2 Storage Methods
  def has_r2_file?
    r2_file_key.present?
  end

  def has_file?
    has_r2_file? || document_file.attached?
  end

  def document_name
    if has_r2_file?
      r2_filename
    elsif document_file.attached?
      document_file.filename.to_s
    else
      "No file attached"
    end
  end

  def document_size
    if has_r2_file?
      number_to_human_size(r2_file_size || 0)
    elsif document_file.attached?
      number_to_human_size(document_file.byte_size)
    else
      "0 KB"
    end
  end

  def document_url
    if has_r2_file?
      r2_public_url
    elsif document_file.attached?
      Rails.application.routes.url_helpers.rails_blob_path(document_file, only_path: true)
    else
      nil
    end
  end

  def is_profile_image?
    document_type == 'Profile Image'
  end

  def is_image?
    if has_r2_file?
      r2_content_type&.start_with?('image/')
    elsif document_file.attached?
      document_file.content_type&.start_with?('image/')
    else
      false
    end
  end

  def r2_public_url
    return nil unless has_r2_file?

    begin
      R2Service.public_url(r2_file_key)
    rescue => e
      Rails.logger.error "Error generating R2 URL for SubAgentDocument: #{e.message}"
      nil
    end
  end

  # Upload file to R2 and store metadata
  def upload_to_r2(file)
    return false unless file.present?

    begin
      # Upload using R2Service
      result = R2Service.upload(file, folder: "sub_agent_documents/#{sub_agent_id}")

      if result[:error]
        Rails.logger.error "Error uploading SubAgentDocument to R2: #{result[:error]}"
        return false
      end

      # Store metadata
      self.r2_file_key = result[:key]
      self.r2_filename = result[:filename]
      self.r2_content_type = result[:content_type]
      self.r2_file_size = result[:size]

      save!
      true
    rescue => e
      Rails.logger.error "Error uploading SubAgentDocument to R2: #{e.message}"
      false
    end
  end

  # Delete file from R2
  def delete_from_r2
    return unless has_r2_file?

    begin
      # Delete using R2Service
      success = R2Service.delete(r2_file_key)

      if success
        # Clear metadata
        update_columns(
          r2_file_key: nil,
          r2_filename: nil,
          r2_content_type: nil,
          r2_file_size: nil
        )
      end

      success
    rescue => e
      Rails.logger.error "Error deleting SubAgentDocument from R2: #{e.message}"
      false
    end
  end

  private

  def file_presence
    return if has_file?
    errors.add(:base, "Document file must be attached")
  end

  def validate_file_size
    file_size = if has_r2_file?
                  r2_file_size
                elsif document_file.attached?
                  document_file.blob.byte_size
                else
                  return
                end

    if file_size > 10.megabytes
      errors.add(:document_file, 'size should be less than 10MB')
    end
  end

  def number_to_human_size(number)
    ActionController::Base.helpers.number_to_human_size(number)
  end
end