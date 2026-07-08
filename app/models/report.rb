class Report < ApplicationRecord
  validates :name, presence: true
  validates :report_type, presence: true

  enum :report_type, {
    commission: 'commission',
    expired_insurance: 'expired_insurance',
    payment_due: 'payment_due',
    upcoming_renewal: 'upcoming_renewal',
    upcoming_payment: 'upcoming_payment',
    leads: 'leads',
    sessions: 'sessions'
  }

  belongs_to :created_by, class_name: 'User', foreign_key: 'created_by_id', optional: true

  scope :active, -> { where(status: true) }
  scope :recent, -> { order(created_at: :desc) }

  serialize :filters, coder: JSON
  serialize :report_data, coder: JSON

  def self.generate_detailed_commission_report(filters = {})
    # Build the base query
    payouts = CommissionPayout.includes(:payout)

    # Apply filters
    if filters[:start_date].present?
      payouts = payouts.where('commission_payouts.created_at >= ?', filters[:start_date])
    end

    if filters[:end_date].present?
      payouts = payouts.where('commission_payouts.created_at <= ?', filters[:end_date].end_of_day)
    end

    if filters[:payout_to].present?
      payouts = payouts.where(payout_to: filters[:payout_to])
    end

    if filters[:policy_type].present?
      payouts = payouts.where(policy_type: filters[:policy_type])
    end

    if filters[:status].present?
      payouts = payouts.where(status: filters[:status])
    end

    # Calculate statistics
    total_commission = payouts.sum(:payout_amount) || 0
    total_tds = payouts.to_a.sum { |payout| payout.tds_amount || 0 }

    {
      payouts: payouts.to_a,
      statistics: {
        total_records: payouts.count,
        total_commission: total_commission,
        total_tds: total_tds,
        net_payout: total_commission - total_tds,
        by_type: payouts.group(:payout_to).sum(:payout_amount),
        by_policy_type: payouts.group(:policy_type).sum(:payout_amount),
        by_status: payouts.group(:status).count,
        date_range: {
          start_date: filters[:start_date] || 1.month.ago.to_date,
          end_date: filters[:end_date] || Date.current
        }
      }
    }
  rescue => e
    Rails.logger.error "Error generating detailed commission report: #{e.message}"
    { payouts: [], statistics: { total_records: 0, total_commission: 0, total_tds: 0, net_payout: 0 } }
  end

  def self.generate_commission_report(date_range = '30_days')
    start_date = case date_range
                 when '7_days' then 7.days.ago
                 when '30_days' then 30.days.ago
                 when '3_months' then 3.months.ago
                 when '6_months' then 6.months.ago
                 when '1_year' then 1.year.ago
                 else 30.days.ago
                 end

    {
      total_commission: Policy.where(created_at: start_date..Time.current).sum(:total_premium) * 0.1,
      commission_by_agent: User.where(user_type: ['agent', 'sub_agent'])
                               .joins(:policies)
                               .where(policies: { created_at: start_date..Time.current })
                               .group('users.first_name', 'users.last_name')
                               .sum('policies.total_premium * 0.1')
    }
  rescue => e
    Rails.logger.error "Error generating commission report: #{e.message}"
    { total_commission: 0, commission_by_agent: {} }
  end

  def self.generate_expired_insurance_report
    Policy.where('end_date < ?', Date.current)
          .includes(:customer, :insurance_company)
          .order(:end_date)
  rescue => e
    Rails.logger.error "Error generating expired insurance report: #{e.message}"
    Policy.none
  end

  def self.generate_payment_due_report
    Policy.active
          .where('end_date > ? AND end_date <= ?', Date.current, 30.days.from_now)
          .includes(:customer)
          .order(:end_date)
  rescue => e
    Rails.logger.error "Error generating payment due report: #{e.message}"
    Policy.none
  end
end