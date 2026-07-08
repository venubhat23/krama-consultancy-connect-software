class PayoutDistributionService
  def self.auto_distribute_commission(commission_receipt_id)
    new(commission_receipt_id).auto_distribute
  end

  def self.process_payment(payout_distribution_id, payment_details)
    new.process_payment(payout_distribution_id, payment_details)
  end

  def initialize(commission_receipt_id = nil)
    @commission_receipt = CommissionReceipt.find(commission_receipt_id) if commission_receipt_id
  end

  def auto_distribute
    return false unless @commission_receipt&.received?

    ActiveRecord::Base.transaction do
      # Calculate distribution amounts
      total_commission = @commission_receipt.total_commission_received
      distributions = calculate_distributions(total_commission)

      # Create payout distributions
      distributions.each do |distribution|
        create_payout_distribution(distribution)
      end

      # Update commission receipt status
      @commission_receipt.update!(
        status: 'distributed',
        distribution_date: Date.current,
        notes: [
          @commission_receipt.notes,
          "Auto-distributed on #{Date.current} by system"
        ].compact.join("\n")
      )

      # Create audit log
      create_distribution_audit_log(distributions)
    end

    true
  rescue StandardError => e
    Rails.logger.error "Failed to auto-distribute commission for receipt #{@commission_receipt&.id}: #{e.message}"
    false
  end

  def process_payment(payout_distribution_id, payment_details)
    distribution = PayoutDistribution.find(payout_distribution_id)
    payment_amount = payment_details[:amount].to_f

    return false if payment_amount <= 0
    return false if distribution.fully_paid?

    ActiveRecord::Base.transaction do
      # Update the distribution record
      previous_paid_amount = distribution.paid_amount
      new_paid_amount = [previous_paid_amount + payment_amount, distribution.calculated_amount].min
      new_pending_amount = distribution.calculated_amount - new_paid_amount

      distribution.update!(
        paid_amount: new_paid_amount,
        pending_amount: new_pending_amount,
        status: new_pending_amount > 0 ? 'partial' : 'paid',
        last_payment_date: Date.current,
        payment_mode: payment_details[:payment_mode],
        transaction_id: payment_details[:transaction_id],
        reference_number: payment_details[:reference_number],
        notes: [
          distribution.notes,
          "Payment of ₹#{payment_amount} processed on #{Date.current}"
        ].compact.join("\n")
      )

      # Update related commission payout if exists
      update_related_payout(distribution, payment_amount, payment_details)

      # Create payment audit log
      create_payment_audit_log(distribution, payment_amount, payment_details)
    end

    true
  rescue StandardError => e
    Rails.logger.error "Failed to process payment for distribution #{payout_distribution_id}: #{e.message}"
    false
  end

  private

  def calculate_distributions(total_commission)
    # Default commission distribution percentages
    distribution_rules = {
      'sub_agent' => 40.0,
      'distributor' => 35.0,
      'investor' => 25.0
    }

    distributions = []

    distribution_rules.each do |recipient_type, percentage|
      amount = (total_commission * percentage) / 100.0

      distributions << {
        recipient_type: recipient_type,
        distribution_percentage: percentage,
        calculated_amount: amount,
        paid_amount: 0.0,
        pending_amount: amount,
        status: 'pending'
      }
    end

    distributions
  end

  def create_payout_distribution(distribution_data)
    PayoutDistribution.create!(
      commission_receipt: @commission_receipt,
      recipient_type: distribution_data[:recipient_type],
      recipient_id: find_recipient_id(distribution_data[:recipient_type]),
      distribution_percentage: distribution_data[:distribution_percentage],
      calculated_amount: distribution_data[:calculated_amount],
      paid_amount: distribution_data[:paid_amount],
      pending_amount: distribution_data[:pending_amount],
      status: distribution_data[:status],
      notes: "Auto-generated distribution for #{@commission_receipt.policy_type} policy ##{@commission_receipt.policy_id}"
    )
  end

  def find_recipient_id(recipient_type)
    # Try to find the appropriate recipient ID based on the policy
    policy = find_policy

    return nil unless policy

    case recipient_type
    when 'sub_agent'
      policy.try(:sub_agent_id)
    when 'distributor'
      # For life insurance, there might be a distributor_id
      policy.try(:distributor_id)
    when 'investor'
      # For life insurance, there might be an investor_id
      policy.try(:investor_id)
    else
      nil
    end
  end

  def find_policy
    case @commission_receipt.policy_type
    when 'health'
      HealthInsurance.find_by(id: @commission_receipt.policy_id)
    when 'life'
      LifeInsurance.find_by(id: @commission_receipt.policy_id)
    when 'motor'
      MotorInsurance.find_by(id: @commission_receipt.policy_id)
    else
      nil
    end
  end

  def update_related_payout(distribution, payment_amount, payment_details)
    # Find the related commission payout
    payout = CommissionPayout.find_by(
      policy_type: @commission_receipt.policy_type,
      policy_id: @commission_receipt.policy_id,
      payout_to: distribution.recipient_type
    )

    return unless payout

    # Update payout status if it matches the distribution
    if payout.payout_amount == distribution.calculated_amount
      if distribution.fully_paid?
        payout.update!(
          status: 'paid',
          payment_mode: payment_details[:payment_mode],
          transaction_id: payment_details[:transaction_id],
          reference_number: payment_details[:reference_number],
          processed_by: payment_details[:processed_by] || 'system',
          notes: [
            payout.notes,
            "Payment processed via distribution system on #{Date.current}"
          ].compact.join("\n")
        )
      else
        payout.update!(status: 'processing') if payout.pending?
      end
    end
  end

  def create_distribution_audit_log(distributions)
    PayoutAuditLog.create_log(
      @commission_receipt,
      'auto_distributed',
      'system',
      {
        total_commission: @commission_receipt.total_commission_received,
        distributions_count: distributions.count,
        distribution_details: distributions
      },
      "Auto-distributed ₹#{@commission_receipt.total_commission_received} commission Dr WISE #{distributions.count} recipients",
      'system'
    )
  rescue StandardError => e
    Rails.logger.warn "Failed to create distribution audit log: #{e.message}"
  end

  def create_payment_audit_log(distribution, payment_amount, payment_details)
    PayoutAuditLog.create_log(
      distribution,
      'payment_processed',
      payment_details[:processed_by] || 'system',
      {
        payment_amount: payment_amount,
        payment_mode: payment_details[:payment_mode],
        transaction_id: payment_details[:transaction_id],
        reference_number: payment_details[:reference_number]
      },
      "Payment of ₹#{payment_amount} processed for #{distribution.recipient_type}",
      payment_details[:ip_address] || 'system'
    )
  rescue StandardError => e
    Rails.logger.warn "Failed to create payment audit log: #{e.message}"
  end
end