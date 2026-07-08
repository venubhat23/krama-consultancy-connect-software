class AiReportHistory < ApplicationRecord
  belongs_to :user

  validates :report_type, presence: true
  validates :confidence_score, presence: true,
            numericality: { greater_than: 0, less_than_or_equal_to: 100 }

  # No serialize needed - columns are already json type

  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(report_type: type) }
  scope :high_confidence, -> { where('confidence_score > ?', 70) }

  def formatted_filters
    return 'No filters' if filters.blank?
    filters.map { |k, v| "#{k.humanize}: #{v}" }.join(', ')
  end

  def insights_summary
    ai_insights&.dig('summary') || 'No summary available'
  end

  def report_type_humanized
    report_type.humanize.titleize
  end
end