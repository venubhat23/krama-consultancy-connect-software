class Invoice < ApplicationRecord
  has_many :invoice_items, dependent: :destroy

  validates :invoice_number, presence: true, uniqueness: true
  validates :payout_type, presence: true, inclusion: { in: %w[affiliate distributor ambassador commission] }
  validates :payout_id, presence: true
  validates :total_amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[pending paid cancelled] }
  validates :invoice_date, presence: true
  validates :due_date, presence: true

  scope :pending, -> { where(status: 'pending') }
  scope :paid, -> { where(status: 'paid') }
  scope :overdue, -> { where('due_date < ? AND status = ?', Date.current, 'pending') }

  # Polymorphic association to get the payout record
  def payout_record
    case payout_type
    when 'affiliate'
      # First try with payout_to filter, if not found try without filter for backward compatibility
      CommissionPayout.find_by(id: payout_id, payout_to: 'affiliate') ||
      CommissionPayout.find_by(id: payout_id)
    when 'distributor'
      # For distributor, payout_id is the distributor ID, not DistributorPayout ID
      # Return the first paid payout for display purposes
      DistributorPayout.where(distributor_id: payout_id, status: 'paid').first
    when 'ambassador'
      # For ambassador, payout_id is the distributor ID
      # Find relevant commission payout
      distributor = Distributor.find_by(id: payout_id)
      if distributor
        # Find a paid ambassador commission payout for this distributor
        # Check each insurance type for policies with this distributor
        ['health', 'life', 'motor', 'other'].each do |policy_type|
          model_name = "#{policy_type.capitalize}Insurance"
          model = model_name.constantize rescue nil
          next unless model

          if model.column_names.include?('distributor_id')
            policy_ids = model.where(distributor_id: distributor.id).pluck(:id)

            policy_ids.each do |policy_id|
              payout = CommissionPayout.find_by(
                policy_type: policy_type,
                policy_id: policy_id,
                payout_to: 'ambassador',
                status: 'paid'
              )
              return payout if payout
            end
          end
        end
      end
      nil
    when 'commission'
      Payout.find_by(id: payout_id)
    end
  end

  def payout_recipient
    case payout_type
    when 'affiliate'
      # For affiliate type, payout_id refers to SubAgent ID
      sub_agent = SubAgent.find_by(id: payout_id)
      if sub_agent
        "#{sub_agent.first_name} #{sub_agent.last_name}".strip
      else
        'Unknown Affiliate'
      end
    when 'distributor'
      # For distributor invoices, payout_id is the distributor ID
      distributor = Distributor.find_by(id: payout_id)
      distributor&.display_name || 'Unknown Distributor'
    when 'ambassador'
      # For ambassador invoices, payout_id is the distributor ID
      distributor = Distributor.find_by(id: payout_id)
      distributor&.display_name || 'Unknown Ambassador'
    when 'commission'
      'Main Agent Commission'
    else
      'Unknown'
    end
  end

  def payout_amount
    # For affiliate invoices, payout_id is the SubAgent ID, not a payout record ID
    # The total_amount already contains the correct sum of all commissions
    if payout_type == 'affiliate'
      return total_amount
    end

    payout = payout_record
    return total_amount unless payout

    case payout.class.name
    when 'CommissionPayout'
      payout.payout_amount || total_amount
    when 'DistributorPayout'
      payout.payout_amount || total_amount
    when 'Payout'
      payout.total_commission_amount || payout.total_amount || total_amount
    else
      total_amount
    end
  end

  def formatted_amount
    amount = payout_amount
    "₹#{amount.to_f.round(2).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  end

  def overdue?
    due_date < Date.current && status == 'pending'
  end

  def days_overdue
    return 0 unless overdue?
    (Date.current - due_date).to_i
  end

  def mark_as_paid!
    update!(status: 'paid', paid_at: Time.current)
  end

  def policy_number
    payout = payout_record
    return 'N/A' unless payout

    policy = get_policy_from_payout(payout)
    policy&.policy_number || 'N/A'
  end

  private

  def get_policy_from_payout(payout)
    case payout.class.name
    when 'CommissionPayout'
      get_policy_from_commission_payout(payout)
    when 'DistributorPayout'
      get_policy_from_commission_payout(payout)
    when 'Payout'
      # For main agent payouts, get the policy directly from the Payout model
      case payout.policy_type
      when 'health'
        HealthInsurance.find_by(id: payout.policy_id)
      when 'life'
        LifeInsurance.find_by(id: payout.policy_id)
      when 'motor'
        MotorInsurance.find_by(id: payout.policy_id)
      when 'other'
        OtherInsurance.find_by(id: payout.policy_id)
      end
    end
  end

  def get_policy_from_commission_payout(commission_payout)
    case commission_payout.policy_type
    when 'health'
      HealthInsurance.find_by(id: commission_payout.policy_id)
    when 'life'
      LifeInsurance.find_by(id: commission_payout.policy_id)
    when 'motor'
      MotorInsurance.find_by(id: commission_payout.policy_id)
    when 'other'
      OtherInsurance.find_by(id: commission_payout.policy_id)
    end
  end
end
