class CommissionReceipt < ApplicationRecord
  include PgSearch::Model

  # Associations
  has_many :payout_distributions, dependent: :destroy
  has_many :payout_audit_logs, as: :auditable, dependent: :destroy

  # Validations
  validates :policy_type, presence: true, inclusion: { in: ['health', 'life', 'motor', 'other'] }
  validates :policy_id, presence: true, numericality: { greater_than: 0 }
  validates :total_commission_received, presence: true, numericality: { greater_than: 0 }
  validates :received_date, presence: true
  validates :insurance_company_name, presence: true
  validates :payment_mode, inclusion: { in: ['bank_transfer', 'cheque', 'online', 'cash'] }, allow_blank: true

  # Scopes
  scope :recent, -> { order(received_date: :desc) }
  scope :for_policy_type, ->(type) { where(policy_type: type) }
  scope :distributed, -> { where(auto_distributed: true) }
  scope :pending_distribution, -> { where(auto_distributed: false) }
  scope :by_company, ->(company) { where(insurance_company_name: company) }

  # Search configuration
  pg_search_scope :search_receipts,
    against: [:insurance_company_name, :insurance_company_reference, :transaction_id],
    using: {
      tsearch: { prefix: true, any_word: true }
    }

  # Callbacks
  after_create :create_audit_log
  after_update :create_audit_log, if: :saved_changes?

  # Instance methods
  def policy
    case policy_type
    when 'health'
      HealthInsurance.find_by(id: policy_id)
    when 'life'
      LifeInsurance.find_by(id: policy_id)
    when 'motor'
      MotorInsurance.find_by(id: policy_id)
    when 'other'
      OtherInsurance.find_by(id: policy_id)
    end
  end

  def customer
    policy&.customer
  end

  def policy_number
    policy&.policy_number
  end

  def total_distributed_amount
    payout_distributions.sum(:calculated_amount)
  end

  def total_paid_amount
    payout_distributions.sum(:paid_amount)
  end

  def total_pending_amount
    payout_distributions.sum(:pending_amount)
  end

  def distribution_complete?
    auto_distributed && payout_distributions.all? { |pd| pd.status == 'paid' }
  end

  def can_auto_distribute?
    !auto_distributed && policy.present?
  end

  def auto_distribute_commission!
    return false if auto_distributed || policy.blank?

    transaction do
      # Get distribution percentages from policy or default settings
      distributions = calculate_distribution_breakdown

      distributions.each do |dist|
        payout_distributions.create!(
          recipient_type: dist[:recipient_type],
          recipient_id: dist[:recipient_id],
          distribution_percentage: dist[:percentage],
          calculated_amount: dist[:amount],
          pending_amount: dist[:amount],
          status: 'pending'
        )
      end

      update!(auto_distributed: true, distributed_at: Time.current)
      create_audit_log('auto_distributed', 'Commission automatically distributed')
    end

    true
  rescue => e
    Rails.logger.error "Error auto-distributing commission for receipt #{id}: #{e.message}"
    false
  end

  private

  def calculate_distribution_breakdown
    distributions = []
    policy_obj = policy
    return distributions unless policy_obj

    # Get associated entities
    sub_agent = policy_obj.try(:sub_agent)
    distributor = policy_obj.try(:distributor)
    investor = policy_obj.try(:investor)

    # Default distribution percentages (can be made configurable)
    sub_agent_percentage = 40.0
    distributor_percentage = 35.0
    investor_percentage = 25.0

    # Calculate amounts
    if sub_agent
      amount = (total_commission_received * sub_agent_percentage) / 100.0
      distributions << {
        recipient_type: 'sub_agent',
        recipient_id: sub_agent.id,
        percentage: sub_agent_percentage,
        amount: amount
      }
    end

    if distributor
      amount = (total_commission_received * distributor_percentage) / 100.0
      distributions << {
        recipient_type: 'distributor',
        recipient_id: distributor.id,
        percentage: distributor_percentage,
        amount: amount
      }
    end

    if investor
      amount = (total_commission_received * investor_percentage) / 100.0
      distributions << {
        recipient_type: 'investor',
        recipient_id: investor.id,
        percentage: investor_percentage,
        amount: amount
      }
    end

    distributions
  end

  def create_audit_log(action = nil, notes = nil)
    action ||= if saved_changes.key?('created_at')
                 'created'
               else
                 'updated'
               end

    payout_audit_logs.create!(
      action: action,
      changes: saved_changes.except('updated_at').to_json,
      performed_by: 'system',
      notes: notes
    )
  end
end