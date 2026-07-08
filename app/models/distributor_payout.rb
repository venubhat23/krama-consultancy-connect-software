class DistributorPayout < ApplicationRecord
  belongs_to :distributor

  validates :policy_type, presence: true, inclusion: { in: %w[health life motor other] }
  validates :policy_id, presence: true
  validates :payout_amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[pending paid cancelled] }

  scope :pending, -> { where(status: 'pending') }
  scope :paid, -> { where(status: 'paid') }
  scope :for_distributor, ->(distributor_id) { where(distributor_id: distributor_id) }
  scope :for_policy, ->(policy_type, policy_id) { where(policy_type: policy_type, policy_id: policy_id) }

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

  def mark_as_paid!(transaction_id: nil, payment_date: nil, notes: nil, processed_by: nil)
    update!(
      status: 'paid',
      transaction_id: transaction_id,
      payout_date: payment_date || Date.current,
      notes: notes,
      processed_by: processed_by,
      processed_at: Time.current
    )
  end
end
