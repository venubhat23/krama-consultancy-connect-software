class Banner < ApplicationRecord
  # Active Storage attachment for banner image
  has_one_attached :banner_image

  # R2 Document Management (keeping existing banner_documents)
  has_many :banner_documents, dependent: :destroy
  accepts_nested_attributes_for :banner_documents, allow_destroy: true, reject_if: :all_blank

  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 500 }
  validates :display_start_date, :display_end_date, presence: true
  validates :display_location, inclusion: { in: ['dashboard', 'login', 'home', 'sidebar'] }, allow_blank: true
  validates :status, inclusion: { in: [true, false] }
  validates :display_order, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :redirect_link, format: { with: URI::regexp }, allow_blank: true
  validates :r2_file_key, presence: true, if: :should_validate_r2_file?

  # Set default values
  before_validation :set_default_display_location

  # Custom validation for date range
  validate :end_date_after_start_date

  # Scopes
  scope :active, -> { where(status: true) }
  scope :inactive, -> { where(status: false) }
  scope :current, -> { where('display_start_date <= ? AND display_end_date >= ?', Date.current, Date.current) }
  scope :by_location, ->(location) { where(display_location: location) }
  scope :ordered, -> { order(:display_order, :created_at) }

  # Enums
  enum :display_location, { dashboard: 'dashboard', login: 'login', home: 'home', sidebar: 'sidebar' }

  # Instance methods
  def active?
    status && current?
  end

  def current?
    Date.current.between?(display_start_date, display_end_date)
  end

  def expired?
    display_end_date < Date.current
  end

  def upcoming?
    display_start_date > Date.current
  end

  def display_location_humanized
    display_location.humanize
  end

  # Get banner image URL (prioritize R2, fallback to Active Storage)
  def banner_image_url
    if r2_file_key.present?
      r2_public_url.present? ? r2_public_url : R2Service.public_url(r2_file_key)
    elsif banner_image.attached?
      Rails.application.routes.url_helpers.rails_blob_path(banner_image, only_path: true)
    else
      nil
    end
  end

  # Check if banner has a valid R2 image
  def has_r2_image?
    r2_file_key.present? && r2_filename.present?
  end

  # Check if banner has any image (R2 or Active Storage)
  def has_image?
    has_r2_image? || banner_image.attached?
  end

  # Human readable file size for banner image
  def formatted_file_size
    return 'Unknown' unless r2_file_size.present?
    ActionController::Base.helpers.number_to_human_size(r2_file_size)
  end

  private

  def set_default_display_location
    self.display_location = 'home' if display_location.blank?
  end

  def end_date_after_start_date
    return unless display_start_date && display_end_date

    if display_end_date < display_start_date
      errors.add(:display_end_date, 'must be after start date')
    end
  end

  # Only validate R2 file key if we're not being destroyed and have actual file content
  def should_validate_r2_file?
    return false if marked_for_destruction?

    # Only require r2_file_key if we have other file-related data
    r2_filename.present? || r2_content_type.present? || r2_file_size.present?
  end
end
