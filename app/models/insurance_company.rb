class InsuranceCompany < ApplicationRecord
  has_many :brokers, dependent: :nullify

  validates :name, presence: true
  validates :insurance_type, presence: true, inclusion: { in: %w[health life motor_other] }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  # Scopes for better query performance
  scope :active, -> { where(status: true) }
  scope :inactive, -> { where(status: false) }
  scope :by_type, ->(type) { where(insurance_type: type) if type.present? }
  scope :health_insurance, -> { where(insurance_type: 'health') }
  scope :life_insurance, -> { where(insurance_type: 'life') }
  scope :motor_other_insurance, -> { where(insurance_type: 'motor_other') }

  # Optimized search scope with better performance
  scope :search, ->(query) {
    return all if query.blank?

    # Use ILIKE with indexes for PostgreSQL, LIKE for others
    if ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
      # Use trigram similarity for better performance
      where(
        "name ILIKE ? OR code ILIKE ? OR contact_person ILIKE ?",
        "%#{query}%", "%#{query}%", "%#{query}%"
      ).order(
        Arel.sql("similarity(name, #{connection.quote(query)}) DESC, name ASC")
      )
    else
      where(
        "name LIKE ? OR code LIKE ? OR contact_person LIKE ?",
        "%#{query}%", "%#{query}%", "%#{query}%"
      )
    end
  }

  # Optimized scope for ordered results
  scope :ordered_by_name, -> { order(:name, :id) }
  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  # Class methods for statistics with caching
  class << self
    def statistics_cached(expires_in: 5.minutes)
      Rails.cache.fetch("insurance_companies_stats", expires_in: expires_in) do
        {
          total: count,
          life: life_insurance.count,
          health: health_insurance.count,
          motor_other: motor_other_insurance.count,
          active: active.count,
          inactive: inactive.count
        }
      end
    end

    # Optimized batch statistics query
    def statistics_batch
      stats = group(:insurance_type).count
      {
        total: count,
        life: stats['life'] || 0,
        health: stats['health'] || 0,
        motor_other: stats['motor_other'] || 0
      }
    end

    # Efficient search and filter combination
    def search_and_filter(search_query: nil, insurance_type: nil, status: nil, page: 1, per_page: 20)
      relation = includes(:brokers) # Prevent N+1 if brokers are accessed
      relation = relation.search(search_query) if search_query.present?
      relation = relation.by_type(insurance_type) if insurance_type.present?
      relation = relation.where(status: status) if !status.nil?

      # Use efficient pagination
      relation.ordered_by_name.offset((page.to_i - 1) * per_page.to_i).limit(per_page.to_i)
    end
  end

  # Instance methods
  def display_type
    case insurance_type
    when 'health'
      'Health Insurance'
    when 'life'
      'Life Insurance'
    when 'motor_other'
      'Motor and Other Insurance'
    else
      insurance_type&.humanize || 'Unknown'
    end
  end

  def display_status
    status? ? 'Active' : 'Inactive'
  end

  def short_name
    code.present? ? code : name.split.map(&:first).join.upcase[0..5]
  end

  # Check if company can be safely deleted
  def can_be_deleted?
    brokers.empty? # Add more associations as needed
  end

  # Callback to clear cache when data changes
  after_save :clear_statistics_cache
  after_destroy :clear_statistics_cache

  private

  def clear_statistics_cache
    Rails.cache.delete("insurance_companies_stats")
  end
end
