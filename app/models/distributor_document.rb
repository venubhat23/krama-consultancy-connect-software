class DistributorDocument < ApplicationRecord
  # Associations
  belongs_to :distributor

  # Attributes for file upload handling
  attr_accessor :document_file

  # Validations
  validates :document_type, presence: true
  validates :document_type, inclusion: {
    in: ['Aadhaar Card', 'Pancard', 'Driving License', 'Mediclaim', 'RC Book', 'Other File', 'Profile Image']
  }
  validate :document_file_presence_or_r2_fields
  validate :validate_document_file_size

  # Callbacks
  before_save :upload_to_r2, if: :document_file_changed?

  private

  def document_file_presence_or_r2_fields
    if document_file.blank? && r2_file_key.blank?
      errors.add(:document_file, "must be attached")
    end
  end

  def document_file_changed?
    document_file.present?
  end

  def upload_to_r2
    return unless document_file.present?

    begin
      # Upload to R2
      result = R2Service.upload(document_file, folder: 'distributor_documents')

      if result[:error]
        errors.add(:document_file, "Upload failed: #{result[:error]}")
        throw :abort
      else
        # Store R2 information
        self.r2_file_key = result[:key]
        self.r2_filename = result[:filename]
        self.r2_content_type = result[:content_type]
        self.r2_file_size = result[:size]

        Rails.logger.info "✅ Uploaded distributor document to R2: #{result[:key]}"
      end
    rescue => e
      Rails.logger.error "❌ R2 upload failed: #{e.message}"
      errors.add(:document_file, "Upload failed: #{e.message}")
      throw :abort
    end
  end

  def validate_document_file_size
    return unless document_file.present?

    if document_file.size > 10.megabytes
      errors.add(:document_file, 'size should be less than 10MB')
    end
  end

  public

  # Instance methods
  def document_name
    r2_filename.presence || "No file attached"
  end

  def document_size
    r2_file_size.present? ? number_to_human_size(r2_file_size) : "0 KB"
  end

  def document_url
    r2_file_key.present? ? R2Service.public_url(r2_file_key) : nil
  end

  def has_document?
    r2_file_key.present?
  end

  def file_extension
    return '' unless r2_filename.present?
    File.extname(r2_filename).downcase
  end

  def is_image?
    image_extensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp']
    image_extensions.include?(file_extension)
  end

  def is_pdf?
    file_extension == '.pdf'
  end

  private

  def number_to_human_size(number)
    ActionController::Base.helpers.number_to_human_size(number)
  end
end
