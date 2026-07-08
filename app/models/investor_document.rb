class InvestorDocument < ApplicationRecord
  # Associations
  belongs_to :investor

  # Legacy ActiveStorage support (for existing documents)
  has_one_attached :document_file

  # Validations
  validates :document_type, presence: true
  validates :document_type, inclusion: {
    in: ['Aadhaar Card', 'Pancard', 'Driving License', 'Mediclaim', 'RC Book', 'Other File']
  }

  # R2 File Storage fields: r2_file_key, r2_filename, r2_content_type, r2_file_size
  # Note: Validation is conditional to support legacy ActiveStorage documents
  validates :r2_file_key, presence: true, unless: :legacy_activestorage_document?
  validates :r2_filename, presence: true, unless: :legacy_activestorage_document?

  # Instance methods
  def document_name
    if r2_filename.present?
      r2_filename
    elsif document_file.attached?
      document_file.filename.to_s
    else
      "No file attached"
    end
  end

  def document_size
    if r2_file_size.present?
      number_to_human_size(r2_file_size)
    elsif document_file.attached?
      number_to_human_size(document_file.byte_size)
    else
      "0 KB"
    end
  end

  def document_url
    if r2_file_key.present?
      R2Service.public_url(r2_file_key)
    elsif document_file.attached?
      # Legacy ActiveStorage URL
      if document_file.service_name.to_s == 'cloudflare_r2'
        "https://pub-54653c57ac144e4a820943b13bf076de.r2.dev/#{document_file.blob.key}"
      else
        Rails.application.routes.url_helpers.rails_blob_path(document_file, only_path: true)
      end
    else
      nil
    end
  end

  def public_document_url
    document_url
  end

  def has_r2_document?
    r2_file_key.present?
  end

  def legacy_activestorage_document?
    document_file.attached? && r2_file_key.blank?
  end

  def content_type
    r2_content_type.presence || (document_file.attached? ? document_file.blob.content_type : nil)
  end

  # R2 Upload Methods
  def upload_to_r2(file)
    result = R2Service.upload(file, folder: "investors/#{investor_id}/documents")

    if result[:error]
      errors.add(:base, "Upload failed: #{result[:error]}")
      return false
    end

    # Store R2 file information
    update!(
      r2_file_key: result[:key],
      r2_filename: result[:filename],
      r2_content_type: result[:content_type],
      r2_file_size: result[:size]
    )

    result
  end

  def delete_from_r2
    return unless r2_file_key.present?

    R2Service.delete(r2_file_key)
    update!(
      r2_file_key: nil,
      r2_filename: nil,
      r2_content_type: nil,
      r2_file_size: nil
    )
  end

  private

  def number_to_human_size(number)
    ActionController::Base.helpers.number_to_human_size(number)
  end
end
