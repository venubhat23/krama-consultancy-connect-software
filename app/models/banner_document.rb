class BannerDocument < ApplicationRecord
  belongs_to :banner

  # Virtual attribute for file uploads during form processing
  attr_accessor :document_file

  # Callbacks
  after_save :upload_document_file, if: :should_upload_file?

  # R2 File Storage - Direct upload to Cloudflare R2
  # Uses columns: r2_file_key, r2_filename, r2_content_type, r2_file_size

  validates :document_type, presence: true
  validates :title, presence: true

  DOCUMENT_TYPES = [
    'Banner Image', 'Promotional Material', 'Logo', 'Background Image',
    'Graphic Asset', 'Marketing Material', 'Other'
  ].freeze

  ALLOWED_FILE_TYPES = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp',
                        'image/gif', 'application/pdf'].freeze

  validates :document_type, inclusion: { in: DOCUMENT_TYPES }

  scope :by_type, ->(type) { where(document_type: type) }
  scope :recent, -> { order(created_at: :desc) }

  # Instance methods for R2 file handling
  def document_name
    r2_filename.present? ? r2_filename : "No file attached"
  end

  def document_size
    return "0 KB" unless r2_file_size.present? && r2_file_size > 0
    number_to_human_size(r2_file_size)
  end

  def document_url
    return nil unless r2_file_key.present?
    "#{R2_CONFIG[:public_url]}/#{r2_file_key}"
  end

  def public_document_url
    document_url
  end

  def download_url
    return nil unless r2_file_key.present?
    base_url = document_url
    return base_url unless base_url.present?
    "#{base_url}?response-content-disposition=attachment;filename=#{CGI.escape(r2_filename || 'document')}"
  end

  def has_file?
    r2_file_key.present?
  end

  def file_type
    r2_content_type
  end

  def filename
    document_name
  end

  def file_size
    r2_file_size
  end

  def file_size_mb
    return 0 unless r2_file_size
    (r2_file_size.to_f / 1.megabyte).round(2)
  end

  def file_extension
    return '' unless r2_filename
    File.extname(r2_filename).downcase
  end

  def human_file_type
    case file_type
    when 'application/pdf'
      'PDF Document'
    when 'image/jpeg', 'image/jpg'
      'JPEG Image'
    when 'image/png'
      'PNG Image'
    when 'image/webp'
      'WebP Image'
    when 'image/gif'
      'GIF Image'
    else
      'Unknown'
    end
  end

  def file_icon
    case file_type
    when 'application/pdf'
      'file-earmark-pdf'
    when 'image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif'
      'file-earmark-image'
    else
      'file-earmark'
    end
  end

  # R2 Upload method
  def upload_to_r2(file_param)
    return false unless file_param.present?

    unless valid_file_type?(file_param.content_type)
      errors.add(:base, 'File must be an image (JPEG, PNG, WebP, GIF) or PDF')
      return false
    end

    if file_param.size > 10.megabytes
      errors.add(:base, 'File must be less than 10MB')
      return false
    end

    begin
      result = R2Service.upload(file_param, folder: "banner_documents/#{banner_id}")

      if result[:key]
        update!(
          r2_file_key: result[:key],
          r2_filename: result[:filename],
          r2_content_type: result[:content_type],
          r2_file_size: result[:size]
        )
        return { success: true, key: result[:key], public_url: result[:public_url] }
      else
        errors.add(:base, "Upload failed: #{result[:error]}")
        return { error: result[:error] }
      end
    rescue => e
      errors.add(:base, "Upload failed: #{e.message}")
      return { error: e.message }
    end
  end

  # Delete from R2
  def delete_from_r2
    return true unless r2_file_key.present?

    begin
      result = R2Service.delete(r2_file_key)

      update!(
        r2_file_key: nil,
        r2_filename: nil,
        r2_content_type: nil,
        r2_file_size: nil
      )

      return result
    rescue => e
      Rails.logger.error "Failed to delete banner document from R2: #{e.message}"
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

  def should_upload_file?
    document_file.present? && r2_file_key.blank?
  end

  def upload_document_file
    return unless document_file.present?

    result = upload_to_r2(document_file)
    unless result[:success]
      Rails.logger.error "Failed to upload banner document file in callback: #{result[:error]}"
    end
  end
end
