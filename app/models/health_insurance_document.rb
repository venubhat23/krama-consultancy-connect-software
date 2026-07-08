class HealthInsuranceDocument < ApplicationRecord
  belongs_to :health_insurance

  validates :title, presence: true
  validates :document_type, presence: true
  validates :r2_file_key, presence: true, if: :should_validate_r2_file?

  # Document type options
  DOCUMENT_TYPES = [
    'policy_document',
    'medical_report',
    'identity_proof',
    'address_proof',
    'income_proof',
    'aadhar',
    'pan_card',
    'passport',
    'previous_policy',
    'claim_form',
    'discharge_summary',
    'pre_policy_checkup',
    'prescription',
    'lab_report',
    'other'
  ].freeze

  validates :document_type, inclusion: { in: DOCUMENT_TYPES }

  # Generate public URL for R2 stored document
  def document_url
    return nil unless r2_file_key.present?
    R2Service.public_url(r2_file_key)
  end

  # Generate download URL with content-disposition header
  def download_url
    return nil unless r2_file_key.present?
    base_url = document_url
    return base_url unless base_url.present?
    "#{base_url}?response-content-disposition=attachment;filename=#{CGI.escape(r2_filename || 'document')}"
  end

  # Check if document has a valid R2 file
  def has_r2_file?
    r2_file_key.present? && r2_filename.present?
  end

  # Human readable file size
  def formatted_file_size
    return 'Unknown' unless r2_file_size.present?
    ActionController::Base.helpers.number_to_human_size(r2_file_size)
  end

  private

  # Only validate R2 file key if we're not being destroyed and have actual file content
  def should_validate_r2_file?
    return false if marked_for_destruction?

    # Only require r2_file_key if we have other file-related data
    r2_filename.present? || r2_content_type.present? || r2_file_size.present?
  end
end
