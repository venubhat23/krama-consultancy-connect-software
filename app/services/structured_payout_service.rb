class StructuredPayoutService
  def self.create_for_policy(policy, policy_type)
    new(policy, policy_type).create_structured_payout
  end

  def initialize(policy, policy_type)
    @policy = policy
    @policy_type = policy_type
    @customer = policy.customer
  end

  def create_structured_payout
    return unless @policy && @customer

    # Skip commission payouts for non-drwise policies
    if @policy.respond_to?(:product_through_dr) && !@policy.product_through_dr
      Rails.logger.info "Skipping commission payouts for non-drwise policy #{@policy.class.name} ID: #{@policy.id}"
      return nil
    end

    # Calculate total commission amount
    total_commission = calculate_total_commission

    # Create main payout (parent)
    main_payout = create_main_payout(total_commission)

    # Create sub-commission payouts under main payout
    create_sub_commission_payouts(main_payout)

    main_payout
  end

  private

  attr_reader :policy, :policy_type, :customer

  def calculate_total_commission
    # Use net premium as base for total commission calculation
    return @policy.net_premium if @policy.respond_to?(:net_premium) && @policy.net_premium

    case @policy_type
    when 'life'
      calculate_life_commission
    when 'health'
      calculate_health_commission
    when 'motor'
      calculate_motor_commission
    when 'other'
      calculate_other_commission
    else
      0.0
    end
  end

  def calculate_life_commission
    return 0.0 unless @policy.respond_to?(:net_premium) && @policy.net_premium

    # For life insurance, the total commission amount should be the net premium
    # This represents the total commission-eligible amount, not the sum of individual payouts
    @policy.net_premium.to_f
  end

  def calculate_health_commission
    return 0.0 unless @policy.respond_to?(:net_premium) && @policy.net_premium

    # Use existing commission fields or calculate defaults
    main_agent_commission = @policy.try(:commission_amount) || 0
    affiliate_commission = @policy.try(:sub_agent_commission_amount) || 0
    ambassador_commission = @policy.try(:ambassador_commission_amount) || 0
    investor_commission = @policy.try(:investor_commission_amount) || 0
    company_expense = calculate_company_expense

    main_agent_commission + affiliate_commission + ambassador_commission + investor_commission + company_expense
  end

  def calculate_motor_commission
    return 0.0 unless @policy.respond_to?(:net_premium) && @policy.net_premium

    # Use existing commission fields or calculate defaults
    main_agent_commission = @policy.try(:main_agent_commission_amount) || (@policy.net_premium * 0.15)
    affiliate_commission = @policy.try(:sub_agent_commission_amount) || (@policy.net_premium * 0.02)
    ambassador_commission = @policy.try(:ambassador_commission_amount) || (@policy.net_premium * 0.02)
    investor_commission = @policy.try(:investor_commission_amount) || (@policy.net_premium * 0.02)
    company_expense = calculate_company_expense

    main_agent_commission + affiliate_commission + ambassador_commission + investor_commission + company_expense
  end

  def calculate_other_commission
    return 0.0 unless @policy.respond_to?(:net_premium) && @policy.net_premium

    # Use existing commission fields similar to health insurance
    main_agent_commission = @policy.try(:commission_amount) || 0
    affiliate_commission = @policy.try(:sub_agent_commission_amount) || 0
    ambassador_commission = @policy.try(:ambassador_commission_amount) || 0
    investor_commission = @policy.try(:investor_commission_amount) || 0
    company_expense = calculate_company_expense

    main_agent_commission + affiliate_commission + ambassador_commission + investor_commission + company_expense
  end

  def calculate_company_expense
    if @policy.respond_to?(:company_expenses_percentage) && @policy.company_expenses_percentage
      (@policy.net_premium * @policy.company_expenses_percentage / 100).to_f
    else
      (@policy.net_premium * 0.02).to_f # Default 2%
    end
  end

  def create_main_payout(total_commission)
    Payout.create!(
      policy_type: @policy_type,
      policy_id: @policy.id,
      customer_id: @customer.id,
      total_commission_amount: total_commission,
      status: 'pending',
      payout_date: calculate_payout_date,
      reference_number: generate_reference_number,
      notes: "Structured payout for #{@policy_type} policy ##{@policy.policy_number}",
      processed_by: 'system_auto',
      net_premium: @policy.try(:net_premium) || 0.0
    )
  end

  def create_sub_commission_payouts(main_payout)
    commissions = [
      create_main_agent_commission(main_payout),
      create_affiliate_commission(main_payout),
      create_ambassador_commission(main_payout),
      create_investor_commission(main_payout),
      create_company_expense_payout(main_payout)
    ].compact

    # Update main payout with commission details
    update_main_payout_with_commission_details(main_payout, commissions)

    commissions
  end

  def create_main_agent_commission(main_payout)
    amount = calculate_main_agent_amount
    return nil if amount <= 0

    CommissionPayout.create!(
      payout_id: main_payout.id,
      policy_type: @policy_type,
      policy_id: @policy.id,
      lead_id: @policy.respond_to?(:lead_id) ? @policy.lead_id : nil,
      payout_to: 'main_agent',
      payout_amount: amount,
      payout_date: main_payout.payout_date,
      status: 'pending',
      payment_mode: 'bank_transfer',
      reference_number: "MAIN_#{main_payout.id}_#{Time.current.to_i}",
      notes: "Main agent commission for #{@policy_type} policy. Policy Number: #{@policy.policy_number}",
      processed_by: 'system_auto'
    )
  end

  def create_affiliate_commission(main_payout)
    amount = calculate_affiliate_amount
    return nil if amount <= 0 || !@policy.respond_to?(:sub_agent_id) || !@policy.sub_agent_id

    CommissionPayout.create!(
      payout_id: main_payout.id,
      policy_type: @policy_type,
      policy_id: @policy.id,
      lead_id: @policy.respond_to?(:lead_id) ? @policy.lead_id : nil,
      payout_to: 'affiliate',
      payout_amount: amount,
      payout_date: main_payout.payout_date,
      status: 'pending',
      payment_mode: 'bank_transfer',
      reference_number: "AFF_#{main_payout.id}_#{Time.current.to_i}",
      notes: "Affiliate commission for #{@policy_type} policy. Sub-agent ID: #{@policy.sub_agent_id}",
      processed_by: 'system_auto'
    )
  end

  def create_ambassador_commission(main_payout)
    amount = calculate_ambassador_amount
    return nil if amount <= 0

    # Check if policy has distributor_id field (for backward compatibility)
    distributor_note = if @policy.respond_to?(:distributor_id) && @policy.distributor_id
      ". Distributor ID: #{@policy.distributor_id}"
    else
      ""
    end

    CommissionPayout.create!(
      payout_id: main_payout.id,
      policy_type: @policy_type,
      policy_id: @policy.id,
      lead_id: @policy.respond_to?(:lead_id) ? @policy.lead_id : nil,
      payout_to: 'ambassador',
      payout_amount: amount,
      payout_date: main_payout.payout_date,
      status: 'pending',
      payment_mode: 'bank_transfer',
      reference_number: "AMB_#{main_payout.id}_#{Time.current.to_i}",
      notes: "Ambassador commission for #{@policy_type} policy#{distributor_note}",
      processed_by: 'system_auto'
    )
  end

  def create_investor_commission(main_payout)
    amount = calculate_investor_amount
    return nil if amount <= 0

    CommissionPayout.create!(
      payout_id: main_payout.id,
      policy_type: @policy_type,
      policy_id: @policy.id,
      lead_id: @policy.respond_to?(:lead_id) ? @policy.lead_id : nil,
      payout_to: 'investor',
      payout_amount: amount,
      payout_date: main_payout.payout_date,
      status: 'pending',
      payment_mode: 'bank_transfer',
      reference_number: "INV_#{main_payout.id}_#{Time.current.to_i}",
      notes: "Investor commission for #{@policy_type} policy. Policy Number: #{@policy.policy_number}",
      processed_by: 'system_auto'
    )
  end

  def create_company_expense_payout(main_payout)
    amount = calculate_company_expense
    return nil if amount <= 0

    CommissionPayout.create!(
      payout_id: main_payout.id,
      policy_type: @policy_type,
      policy_id: @policy.id,
      lead_id: @policy.respond_to?(:lead_id) ? @policy.lead_id : nil,
      payout_to: 'company_expense',
      payout_amount: amount,
      payout_date: main_payout.payout_date,
      status: 'pending',
      payment_mode: 'internal',
      reference_number: "COMP_#{main_payout.id}_#{Time.current.to_i}",
      notes: "Company expense allocation for #{@policy_type} policy",
      processed_by: 'system_auto'
    )
  end

  # Amount calculation methods
  def calculate_main_agent_amount
    case @policy_type
    when 'life'
      @policy.try(:after_tds_value) || @policy.try(:commission_amount) || (@policy.net_premium * 0.10)
    when 'health'
      @policy.try(:commission_amount) || (@policy.net_premium * 0.10)
    when 'motor'
      @policy.try(:main_agent_commission_amount) || (@policy.net_premium * 0.15)
    when 'other'
      @policy.try(:commission_amount) || (@policy.net_premium * 0.10)
    else
      0.0
    end
  end

  def calculate_affiliate_amount
    @policy.try(:sub_agent_after_tds_value) ||
    @policy.try(:sub_agent_commission_amount) ||
    (@policy.net_premium * 0.02)
  end

  def calculate_ambassador_amount
    @policy.try(:ambassador_after_tds_value) ||
    @policy.try(:ambassador_commission_amount) ||
    (@policy.net_premium * 0.02)
  end

  def calculate_investor_amount
    @policy.try(:investor_after_tds_value) ||
    @policy.try(:investor_commission_amount) ||
    (@policy.net_premium * 0.02)
  end

  # Utility methods
  def calculate_payout_date
    # Set payout date to 30 days from policy creation
    (@policy.created_at + 30.days).to_date
  end

  def generate_reference_number
    "PAYOUT_#{@policy_type.upcase}_#{@policy.id}_#{Time.current.to_i}"
  end

  def update_main_payout_with_commission_details(main_payout, commissions)
    commission_details = {}
    commission_summary = []

    commissions.each do |commission|
      case commission.payout_to
      when 'main_agent'
        commission_details.merge!(
          main_agent_commission_amount: commission.payout_amount
        )
        commission_summary << "Main Agent: #{get_policy_percentage(:main_agent)}% (₹#{commission.payout_amount})"

      when 'affiliate'
        commission_details.merge!(
          affiliate_commission_amount: commission.payout_amount
        )
        commission_summary << "Affiliate: #{get_policy_percentage(:affiliate)}% (₹#{commission.payout_amount})"

      when 'ambassador'
        commission_details.merge!(
          ambassador_commission_amount: commission.payout_amount
        )
        commission_summary << "Ambassador: #{get_policy_percentage(:ambassador)}% (₹#{commission.payout_amount})"

      when 'investor'
        commission_details.merge!(
          investor_commission_amount: commission.payout_amount
        )
        commission_summary << "Investor: #{get_policy_percentage(:investor)}% (₹#{commission.payout_amount})"

      when 'company_expense'
        commission_details.merge!(
          company_expense_amount: commission.payout_amount
        )
        commission_summary << "Company Expense: #{get_policy_percentage(:company_expense)}% (₹#{commission.payout_amount})"
      end
    end

    # Commission summary removed - field doesn't exist in Payout model

    # Update main payout with all commission details
    main_payout.update!(commission_details)
  end

  def get_policy_percentage(commission_type)
    case commission_type
    when :main_agent
      @policy.try(:main_agent_commission_percentage) || 0.0
    when :affiliate
      @policy.try(:sub_agent_commission_percentage) || 0.0
    when :ambassador
      @policy.try(:ambassador_commission_percentage) || 0.0
    when :investor
      @policy.try(:investor_commission_percentage) || 0.0
    when :company_expense
      @policy.try(:company_expenses_percentage) || 0.0
    else
      0.0
    end
  end
end