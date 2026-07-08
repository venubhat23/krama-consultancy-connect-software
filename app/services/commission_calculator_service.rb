class CommissionCalculatorService
  # Commission percentage structure based on user requirements
  COMMISSION_RATES = {
    main_agent: 10.0,      # 10% of premium
    affiliate: 2.0,        # 2% of premium
    ambassador: 2.0,       # 2% of premium
    investor: 1.0,         # 1% of premium
    company_expense: 3.0   # 3% of premium (from main agent's share)
  }.freeze

  # Updated commission distribution percentages for main agent, affiliate, distributor
  DEFAULT_DISTRIBUTION_PERCENTAGES = {
    'main_agent' => 50.0,    # Main agent gets 50% of commission
    'affiliate' => 30.0,     # Affiliate (sub_agent) gets 30%
    'distributor' => 20.0    # Distributor gets 20%
  }.freeze

  def self.create_payouts_for_policy(policy)
    new(policy).create_payouts
  end

  def self.create_enhanced_payouts_for_policy(policy)
    new(policy).create_enhanced_payouts
  end

  def self.calculate_commission_breakdown(policy)
    return {} unless policy.respond_to?(:total_premium) && policy.total_premium.present?

    premium = policy.total_premium.to_f

    # Get commission percentages from the policy (if stored) or use defaults
    main_agent_rate = policy.try(:main_agent_commission_percentage) || COMMISSION_RATES[:main_agent]
    affiliate_rate = policy.try(:affiliate_commission_percentage) || COMMISSION_RATES[:affiliate]
    ambassador_rate = policy.try(:ambassador_commission_percentage) || COMMISSION_RATES[:ambassador]
    investor_rate = policy.try(:investor_commission_percentage) || COMMISSION_RATES[:investor]
    company_expense_rate = policy.try(:company_expense_percentage) || COMMISSION_RATES[:company_expense]

    # Calculate base commission amounts
    main_agent_total = premium * (main_agent_rate / 100.0)
    affiliate_commission = premium * (affiliate_rate / 100.0)
    ambassador_commission = premium * (ambassador_rate / 100.0)
    investor_commission = premium * (investor_rate / 100.0)

    # Calculate deductions from main agent commission
    total_deductions = affiliate_commission + ambassador_commission + investor_commission
    company_expense = main_agent_total * (company_expense_rate / 100.0)

    # Main agent's final profit
    main_agent_profit = main_agent_total - total_deductions - company_expense

    {
      premium_amount: premium,
      main_agent: {
        total_commission: main_agent_total,
        deductions: {
          affiliate: affiliate_commission,
          ambassador: ambassador_commission,
          investor: investor_commission,
          company_expense: company_expense,
          total: total_deductions + company_expense
        },
        final_profit: main_agent_profit
      },
      payouts: {
        affiliate: affiliate_commission,
        ambassador: ambassador_commission,
        investor: investor_commission,
        company_expense: company_expense
      },
      summary: {
        total_commission_generated: main_agent_total,
        total_distributed: total_deductions,
        company_expense: company_expense,
        agent_profit: main_agent_profit
      }
    }
  end

  def self.get_policy_commission_summary(policy)
    breakdown = calculate_commission_breakdown(policy)
    return nil if breakdown.empty?

    # Get existing payout records
    policy_type = policy.class.name.underscore.gsub('_insurance', '')
    existing_payouts = CommissionPayout.where(
      policy_type: policy_type,
      policy_id: policy.id
    )

    {
      policy: {
        type: policy_type.titleize,
        number: policy.policy_number,
        customer: policy.customer.display_name,
        premium: breakdown[:premium_amount]
      },
      commission_breakdown: breakdown,
      payout_status: {
        affiliate: get_payout_status(existing_payouts, 'affiliate'),
        ambassador: get_payout_status(existing_payouts, 'ambassador'),
        investor: get_payout_status(existing_payouts, 'investor'),
        company_expense: get_payout_status(existing_payouts, 'company_expense')
      }
    }
  end

  def initialize(policy)
    @policy = policy
    @policy_type = determine_policy_type
    @commission_amount = extract_commission_amount
  end

  def create_payouts
    return false unless valid_policy?

    ActiveRecord::Base.transaction do
      # Create commission receipt first
      commission_receipt = create_commission_receipt

      # Create individual payouts for each distribution type
      DEFAULT_DISTRIBUTION_PERCENTAGES.each do |recipient_type, percentage|
        create_payout_for_recipient(recipient_type, percentage, commission_receipt)
      end

      # Create audit log
      create_audit_log(commission_receipt)
    end

    true
  rescue StandardError => e
    Rails.logger.error "Failed to create payouts for policy #{@policy.id}: #{e.message}"
    false
  end

  def create_enhanced_payouts
    return false unless valid_policy?

    ActiveRecord::Base.transaction do
      policy_type = determine_policy_type

      # Create commission payouts for each role based on the calculated amounts from policy
      create_commission_payout_for_sub_agent if should_create_sub_agent_payout?
      create_commission_payout_for_ambassador if should_create_ambassador_payout?
      create_commission_payout_for_investor if should_create_investor_payout?
      create_commission_payout_for_company_expense if should_create_company_expense_payout?

      # Create specialized distributor payout if distributor exists
      create_distributor_payout if should_create_distributor_payout?

      Rails.logger.info "Successfully created enhanced payouts for #{policy_type} policy #{@policy.id}"
    end

    true
  rescue StandardError => e
    Rails.logger.error "Failed to create enhanced payouts for policy #{@policy.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    false
  end

  private

  def valid_policy?
    @policy.present? && @commission_amount > 0
  end

  def determine_policy_type
    case @policy.class.name
    when 'HealthInsurance'
      'health'
    when 'LifeInsurance'
      'life'
    when 'MotorInsurance'
      'motor'
    else
      'other'
    end
  end

  def extract_commission_amount
    # Try different commission amount fields based on policy type
    @policy.try(:commission_amount) ||
    @policy.try(:main_agent_commission_percentage) ||
    calculate_commission_from_premium ||
    0.0
  end

  def calculate_commission_from_premium
    premium = @policy.try(:total_premium) || @policy.try(:premium_amount) || 0
    commission_percentage = @policy.try(:main_agent_commission_percentage) || 0

    return 0.0 if premium == 0 || commission_percentage == 0

    (premium * commission_percentage) / 100.0
  end

  def create_commission_receipt
    CommissionReceipt.create!(
      policy_type: @policy_type,
      policy_id: @policy.id,
      total_commission_received: @commission_amount,
      received_date: Date.current,
      status: 'received',
      insurance_company_name: extract_insurance_company_name,
      policy_number: @policy.try(:policy_number) || "POL-#{@policy.id}",
      customer_name: extract_customer_name,
      notes: "Auto-created for policy #{@policy.id}"
    )
  end

  def create_payout_for_recipient(recipient_type, percentage, commission_receipt)
    payout_amount = (@commission_amount * percentage) / 100.0

    # Create the main payout entry
    payout = CommissionPayout.create!(
      policy_type: @policy_type,
      policy_id: @policy.id,
      payout_to: recipient_type,
      payout_amount: payout_amount,
      payout_date: calculate_payout_date,
      status: 'pending',
      commission_amount_received: @commission_amount,
      distribution_percentage: percentage,
      processed_by: 'system_auto',
      notes: "Auto-created #{percentage}% distribution for #{recipient_type}"
    )

    # Create the detailed payout distribution entry
    PayoutDistribution.create!(
      commission_receipt: commission_receipt,
      recipient_type: recipient_type,
      recipient_id: find_recipient_id(recipient_type),
      distribution_percentage: percentage,
      calculated_amount: payout_amount,
      paid_amount: 0.0,
      pending_amount: payout_amount,
      status: 'pending',
      notes: "Auto-calculated distribution for #{@policy_type} policy ##{@policy.id}"
    )

    payout
  end

  def calculate_payout_date
    # Schedule payouts for 30 days from policy creation
    Date.current + 30.days
  end

  def find_recipient_id(recipient_type)
    case recipient_type
    when 'affiliate', 'sub_agent'
      @policy.try(:sub_agent_id)
    when 'distributor'
      @policy.try(:distributor_id)
    when 'main_agent'
      # Could be the current user or system admin
      nil
    else
      nil
    end
  end

  def extract_insurance_company_name
    @policy.try(:insurance_company_name) ||
    @policy.try(:insurance_company) ||
    'Unknown Company'
  end

  def extract_customer_name
    if @policy.respond_to?(:customer) && @policy.customer
      @policy.customer.display_name
    else
      'Unknown Customer'
    end
  end

  def create_audit_log(commission_receipt)
    PayoutAuditLog.create_log(
      commission_receipt,
      'auto_created',
      'system',
      {},
      "Automatically created commission distribution for #{@policy_type} policy ##{@policy.id}",
      'system'
    )
  rescue StandardError => e
    # Don't fail the transaction if audit logging fails
    Rails.logger.warn "Failed to create audit log: #{e.message}"
  end

  private

  # Check if we should create payouts based on calculated commission amounts
  def should_create_sub_agent_payout?
    @policy.respond_to?(:sub_agent_commission_amount) &&
    @policy.sub_agent_commission_amount.present? &&
    @policy.sub_agent_commission_amount > 0 &&
    @policy.sub_agent_id.present?
  end

  def should_create_ambassador_payout?
    @policy.respond_to?(:ambassador_commission_amount) &&
    @policy.ambassador_commission_amount.present? &&
    @policy.ambassador_commission_amount > 0
  end

  def should_create_investor_payout?
    @policy.respond_to?(:investor_commission_amount) &&
    @policy.investor_commission_amount.present? &&
    @policy.investor_commission_amount > 0 &&
    @policy.investor_id.present?
  end

  def should_create_company_expense_payout?
    @policy.respond_to?(:profit_amount) &&
    @policy.profit_amount.present? &&
    @policy.profit_amount > 0
  end

  def should_create_distributor_payout?
    return false unless @policy.respond_to?(:distributor_id) && @policy.distributor_id.present?

    # Check if policy has explicit distributor commission amount (like LifeInsurance)
    if @policy.respond_to?(:distributor_commission_amount)
      @policy.distributor_commission_amount.present? && @policy.distributor_commission_amount > 0
    else
      # For policies without explicit distributor commission (like HealthInsurance),
      # create distributor payout using a default percentage of net premium
      @policy.respond_to?(:net_premium) && @policy.net_premium.present? && @policy.net_premium > 0
    end
  end

  # Create commission payout for sub agent (affiliate)
  def create_commission_payout_for_sub_agent
    CommissionPayout.create!(
      policy_type: @policy_type,
      policy_id: @policy.id,
      payout_to: 'affiliate',
      payout_amount: @policy.sub_agent_commission_amount,
      payout_date: calculate_payout_date,
      status: 'pending',
      payment_mode: 'bank_transfer',
      reference_number: generate_reference_number('AFF'),
      notes: "Auto-created affiliate payout for #{@policy_type} policy. Sub-agent ID: #{@policy.sub_agent_id}. TDS Amount: #{@policy.try(:sub_agent_tds_amount)}. After TDS: #{@policy.try(:sub_agent_after_tds_value)}",
      processed_by: 'system_auto'
    )
    Rails.logger.info "Created affiliate payout: #{@policy.sub_agent_commission_amount} for sub_agent_id: #{@policy.sub_agent_id}"
  end

  # Create commission payout for ambassador
  def create_commission_payout_for_ambassador
    CommissionPayout.create!(
      policy_type: @policy_type,
      policy_id: @policy.id,
      payout_to: 'ambassador',
      payout_amount: @policy.ambassador_commission_amount,
      payout_date: calculate_payout_date,
      status: 'pending',
      payment_mode: 'bank_transfer',
      reference_number: generate_reference_number('AMB'),
      notes: "Auto-created ambassador payout for #{@policy_type} policy. TDS Amount: #{@policy.try(:ambassador_tds_amount)}. After TDS: #{@policy.try(:ambassador_after_tds_value)}",
      processed_by: 'system_auto'
    )
    Rails.logger.info "Created ambassador payout: #{@policy.ambassador_commission_amount}"
  end

  # Create commission payout for investor
  def create_commission_payout_for_investor
    CommissionPayout.create!(
      policy_type: @policy_type,
      policy_id: @policy.id,
      payout_to: 'investor',
      payout_amount: @policy.investor_commission_amount,
      payout_date: calculate_payout_date,
      status: 'pending',
      payment_mode: 'bank_transfer',
      reference_number: generate_reference_number('INV'),
      notes: "Auto-created investor payout for #{@policy_type} policy. Investor ID: #{@policy.investor_id}. TDS Amount: #{@policy.try(:investor_tds_amount)}. After TDS: #{@policy.try(:investor_after_tds_value)}",
      processed_by: 'system_auto'
    )
    Rails.logger.info "Created investor payout: #{@policy.investor_commission_amount} for investor_id: #{@policy.investor_id}"
  end

  # Create commission payout for company expense (profit)
  def create_commission_payout_for_company_expense
    CommissionPayout.create!(
      policy_type: @policy_type,
      policy_id: @policy.id,
      payout_to: 'company_expense',
      payout_amount: @policy.profit_amount,
      payout_date: calculate_payout_date,
      status: 'pending',
      payment_mode: 'internal',
      reference_number: generate_reference_number('COMP'),
      notes: "Auto-created company profit for #{@policy_type} policy",
      processed_by: 'system_auto'
    )
    Rails.logger.info "Created company expense payout: #{@policy.profit_amount}"
  end

  # Create specialized distributor payout
  def create_distributor_payout
    # Calculate distributor commission amount
    distributor_amount = if @policy.respond_to?(:distributor_commission_amount) && @policy.distributor_commission_amount.present?
                          @policy.distributor_commission_amount
                        else
                          # Default to 3% of net premium for policies without explicit distributor commission
                          @policy.net_premium * 0.03
                        end

    DistributorPayout.create!(
      distributor_id: @policy.distributor_id,
      policy_type: @policy_type,
      policy_id: @policy.id,
      payout_amount: distributor_amount,
      payout_date: calculate_payout_date,
      status: 'pending',
      payment_mode: 'bank_transfer',
      reference_number: generate_reference_number('DIST'),
      notes: "Auto-created distributor payout for #{@policy_type} policy. TDS Amount: #{@policy.try(:distributor_tds_amount)}. After TDS: #{@policy.try(:distributor_after_tds_value)}",
      processed_by: 'system_auto'
    )
    Rails.logger.info "Created distributor payout: #{distributor_amount} for distributor_id: #{@policy.distributor_id}"
  end

  def generate_reference_number(prefix)
    "#{prefix}_#{@policy.id}_#{Time.current.to_i}"
  end

  def self.get_payout_status(existing_payouts, payout_type)
    payout = existing_payouts.find { |p| p.payout_to == payout_type }
    return { status: 'not_applicable', amount: 0 } unless payout

    {
      status: payout.status,
      amount: payout.payout_amount,
      payout_date: payout.payout_date,
      transaction_id: payout.transaction_id,
      id: payout.id
    }
  end
end