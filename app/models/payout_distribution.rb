class PayoutDistribution < ApplicationRecord
  include PgSearch::Model

  # Associations
  belongs_to :commission_receipt
  has_many :payout_audit_logs, as: :auditable, dependent: :destroy

  # Validations
  validates :recipient_type, presence: true, inclusion: { in: ['sub_agent', 'distributor', 'investor'] }
  validates :recipient_id, presence: true, numericality: { greater_than: 0 }
  validates :distribution_percentage, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :calculated_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :paid_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :pending_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true, inclusion: { in: ['pending', 'partial', 'paid', 'cancelled'] }

  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :partial, -> { where(status: 'partial') }
  scope :paid, -> { where(status: 'paid') }
  scope :for_recipient, ->(type, id) { where(recipient_type: type, recipient_id: id) }
  scope :recent_payments, -> { where.not(payment_date: nil).order(payment_date: :desc) }

  # Search configuration
  pg_search_scope :search_distributions,
    against: [:transaction_id, :reference_number, :payment_notes],
    using: {
      tsearch: { prefix: true, any_word: true }
    }

  # Callbacks
  before_save :calculate_pending_amount
  after_create :create_audit_log
  after_update :create_audit_log, if: :saved_changes?

  # Instance methods
  def recipient
    case recipient_type
    when 'sub_agent'
      SubAgent.find_by(id: recipient_id)
    when 'distributor'
      Distributor.find_by(id: recipient_id)
    when 'investor'
      Investor.find_by(id: recipient_id)
    end
  end

  def recipient_name
    recipient&.display_name || 'Unknown'
  end

  def policy
    commission_receipt.policy
  end

  def policy_number
    commission_receipt.policy_number
  end

  def customer_name
    commission_receipt.customer&.display_name || 'Unknown'
  end

  def can_make_payment?
    pending_amount > 0 && ['pending', 'partial'].include?(status)
  end

  def make_payment!(amount, payment_details = {})
    return false unless can_make_payment?
    return false if amount <= 0 || amount > pending_amount

    transaction do
      self.paid_amount += amount
      self.payment_date = payment_details[:payment_date] || Date.current
      self.payment_mode = payment_details[:payment_mode]
      self.transaction_id = payment_details[:transaction_id]
      self.reference_number = payment_details[:reference_number]
      self.payment_notes = payment_details[:notes]
      self.processed_by = payment_details[:processed_by] || Current.user&.email

      # Update status based on payment completion
      if paid_amount >= calculated_amount
        self.status = 'paid'
        self.pending_amount = 0
      else
        self.status = 'partial'
        self.pending_amount = calculated_amount - paid_amount
      end

      save!
      create_audit_log('payment_made', "Payment of #{amount} made")
    end

    true
  rescue => e
    Rails.logger.error "Error making payment for distribution #{id}: #{e.message}"
    false
  end

  def cancel_payment!(reason = nil)
    return false if status == 'paid'

    transaction do
      self.status = 'cancelled'
      self.payment_notes = [payment_notes, "Cancelled: #{reason}"].compact.join(' | ')
      save!
      create_audit_log('cancelled', reason)
    end

    true
  end

  def payment_summary
    {
      total_amount: calculated_amount,
      paid_amount: paid_amount,
      pending_amount: pending_amount,
      percentage_paid: calculated_amount > 0 ? (paid_amount / calculated_amount * 100).round(2) : 0,
      status: status,
      payment_count: payment_date.present? ? 1 : 0
    }
  end

  # Class methods
  def self.total_pending_for_recipient(recipient_type, recipient_id)
    for_recipient(recipient_type, recipient_id).sum(:pending_amount)
  end

  def self.total_paid_for_recipient(recipient_type, recipient_id)
    for_recipient(recipient_type, recipient_id).sum(:paid_amount)
  end

  def self.monthly_summary(year, month)
    start_date = Date.new(year, month, 1)
    end_date = start_date.end_of_month

    where(payment_date: start_date..end_date).group(:recipient_type).sum(:paid_amount)
  end

  private

  def calculate_pending_amount
    self.pending_amount = calculated_amount - paid_amount
    self.pending_amount = 0 if pending_amount < 0
  end

  def create_audit_log(action = nil, notes = nil)
    action ||= if saved_changes.key?('created_at')
                 'created'
               else
                 'updated'
               end

    payout_audit_logs.create!(
      action: action,
      changes: saved_changes.except('updated_at'),
      performed_by: Current.user&.email || 'system',
      notes: notes
    )
  end
end