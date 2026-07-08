require 'ostruct'

class Admin::AffiliatePayoutsController < Admin::ApplicationController
  before_action :authenticate_user!

  def index
    @affiliate_payouts = calculate_affiliate_payouts
    @total_affiliates = @affiliate_payouts.count
    @total_pending_amount = @affiliate_payouts.sum { |a| a[:pending_amount] }
    @total_paid_amount = @affiliate_payouts.sum { |a| a[:paid_amount] }
    @total_commission_earned = @affiliate_payouts.sum { |a| a[:total_amount] }
  end

  def mark_as_paid
    begin
      affiliate_id = params[:affiliate_id]
      lead_ids = params[:lead_ids] || []
      payout_type = params[:payout_type] || 'multiple_leads' # affiliate_all, lead_single, lead_multiple, affiliate_single

      Rails.logger.info "=== AFFILIATE PAYOUT DEBUG ==="
      Rails.logger.info "affiliate_id: #{affiliate_id}"
      Rails.logger.info "lead_ids: #{lead_ids.inspect}"
      Rails.logger.info "payout_type: #{payout_type}"

      success_count = 0
      errors = []

      case payout_type
      when 'affiliate_all'
        # Mark all pending payouts for this affiliate as paid
        transaction_id = params[:transaction_id]
        payment_date = params[:payment_date]
        notes = params[:notes]

        if lead_ids.any?
          # Use the specific lead_ids from the form with transaction details
          lead_ids.each do |lead_id|
            if transaction_id.present?
              result = mark_single_lead_payout_with_details(lead_id, transaction_id, payment_date, notes)
            else
              result = mark_single_lead_payout(lead_id)
            end
            success_count += 1 if result[:success]
            errors << result[:error] if result[:error]
          end
        else
          # Fallback: find all unpaid leads for this affiliate
          mark_all_affiliate_payouts(affiliate_id)
          success_count = 1
        end
      when 'lead_single'
        # Mark single lead as paid
        single_lead_id = params[:single_lead_id]
        result = mark_single_lead_payout(single_lead_id)
        success_count = result[:success] ? 1 : 0
        errors << result[:error] if result[:error]
      when 'lead_multiple'
        # Mark multiple leads as paid
        lead_ids.each do |lead_id|
          result = mark_single_lead_payout(lead_id)
          success_count += 1 if result[:success]
          errors << result[:error] if result[:error]
        end
      when 'bulk_selection'
        # Handle bulk selection from modal
        affiliate_ids = params[:affiliate_ids] || []

        # Process selected affiliates (all their pending leads)
        affiliate_ids.each do |aff_id|
          mark_all_affiliate_payouts(aff_id)
          success_count += 1
        end

        # Process selected individual leads
        lead_ids.each do |lead_id|
          result = mark_single_lead_payout(lead_id)
          success_count += 1 if result[:success]
          errors << result[:error] if result[:error]
        end
      when 'bulk_modal_selection'
        # Handle new modal bulk selection with transaction details
        transaction_id = params[:transaction_id]
        payment_date = params[:payment_date]
        notes = params[:notes]

        lead_ids.each do |lead_id|
          result = mark_single_lead_payout_with_details(lead_id, transaction_id, payment_date, notes)
          success_count += 1 if result[:success]
          errors << result[:error] if result[:error]
        end
      when 'quick_all_pending'
        # Handle quick payout for all pending affiliate payouts
        transaction_id = params[:transaction_id]
        payment_date = params[:payment_date] || Date.current
        notes = params[:notes] || "Quick batch payout for all pending affiliates"

        # Get all pending affiliate payouts
        pending_payouts = calculate_affiliate_payouts.select { |a| a[:pending_amount] > 0 }

        pending_payouts.each do |affiliate_data|
          unpaid_leads = affiliate_data[:leads].select { |l| !l[:paid] }
          unpaid_leads.each do |lead_data|
            result = mark_single_lead_payout_with_details(lead_data[:lead].lead_id, transaction_id, payment_date, notes)
            success_count += 1 if result[:success]
            errors << result[:error] if result[:error]
          end
        end
      else
        # Default: mark specific affiliate's leads as paid
        lead_ids.each do |lead_id|
          result = mark_single_lead_payout(lead_id)
          success_count += 1 if result[:success]
          errors << result[:error] if result[:error]
        end
      end

      if errors.any?
        redirect_to admin_affiliate_payouts_path, alert: "Some payouts failed: #{errors.join(', ')}"
      else
        # Generate invoices after successful payouts - before redirect
        invoice_generated = generate_affiliate_invoices(affiliate_id, lead_ids, payout_type)

        notice_message = if invoice_generated
          "#{success_count} affiliate payout(s) marked as paid successfully! Invoice has been generated."
        else
          "#{success_count} affiliate payout(s) marked as paid successfully!"
        end

        redirect_to admin_affiliate_payouts_path, notice: notice_message
      end

    rescue StandardError => e
      redirect_to admin_affiliate_payouts_path, alert: "Error processing payouts: #{e.message}"
    end
  end

  def show
    @affiliate_id = params[:id]
    @affiliate = find_affiliate_by_id(@affiliate_id)

    unless @affiliate
      redirect_to admin_affiliate_payouts_path, alert: 'Affiliate not found'
      return
    end

    @affiliate_details = fetch_affiliate_detailed_payouts(@affiliate_id)
    @lead_wise_commissions = @affiliate_details[:lead_wise_commissions]
    @summary = @affiliate_details[:summary]
  end

  def unpaid_data
    unpaid_affiliates = calculate_affiliate_payouts.select { |a| a[:pending_amount] > 0 }

    render json: {
      success: true,
      data: unpaid_affiliates.map do |affiliate_data|
        {
          affiliate: {
            id: affiliate_data[:affiliate].id,
            name: "#{affiliate_data[:affiliate].first_name} #{affiliate_data[:affiliate].last_name}",
            email: affiliate_data[:affiliate].email
          },
          leads: affiliate_data[:leads].reject { |l| l[:paid] }.map do |lead_data|
            {
              id: lead_data[:lead].lead_id,
              policy_id: lead_data[:policy].id,
              commission: lead_data[:commission].round(2),
              policy_number: lead_data[:policy].policy_number,
              customer_name: lead_data[:policy].customer&.display_name || 'Unknown'
            }
          end,
          total_pending: affiliate_data[:pending_amount].round(2)
        }
      end
    }
  rescue StandardError => e
    render json: { success: false, message: e.message }
  end

  private

  def calculate_affiliate_payouts
    payouts = []

    # Get all commission payouts for affiliates directly
    affiliate_commission_payouts = CommissionPayout.where(payout_to: 'affiliate').includes(:payout)

    # Group by affiliate
    affiliate_groups = {}

    affiliate_commission_payouts.each do |commission_payout|
      # Get policy from commission payout
      policy = get_policy_from_commission_payout(commission_payout)
      next unless policy

      # Skip if main agent commission not received
      next unless policy.respond_to?(:main_agent_commission_received) && policy.main_agent_commission_received

      # Get sub_agent from the policy's sub_agent_id
      sub_agent = SubAgent.find_by(id: policy.sub_agent_id) if policy.respond_to?(:sub_agent_id) && policy.sub_agent_id.present?
      next unless sub_agent

      # Get or create lead if needed
      lead = nil
      if commission_payout.lead_id.present?
        lead = Lead.find_by(lead_id: commission_payout.lead_id)
      end

      # Fallback: try to find lead by policy lead_id
      if lead.nil? && policy.respond_to?(:lead_id) && policy.lead_id.present?
        lead = Lead.find_by(lead_id: policy.lead_id)
      end

      # If no lead found, create a virtual lead object for display purposes
      if lead.nil?
        lead = OpenStruct.new(
          id: "virtual_#{policy.id}",
          lead_id: policy.try(:lead_id) || "POLICY-#{policy.id}",
          first_name: policy.try(:customer)&.first_name || 'Unknown',
          last_name: policy.try(:customer)&.last_name || 'Customer',
          email: policy.try(:customer)&.email || '',
          mobile: policy.try(:customer)&.mobile || '',
          created_at: policy.created_at
        )
      end

      affiliate_commission = commission_payout.payout_amount.to_f

      # Check if already paid
      already_paid = commission_payout.status == 'paid'

      affiliate_key = sub_agent.id

      affiliate_groups[affiliate_key] ||= {
        affiliate: sub_agent,
        leads: [],
        total_amount: 0,
        paid_amount: 0,
        pending_amount: 0
      }

      lead_data = {
        lead: lead,
        policy: policy,
        commission: affiliate_commission,
        paid: already_paid
      }

      affiliate_groups[affiliate_key][:leads] << lead_data
      affiliate_groups[affiliate_key][:total_amount] += affiliate_commission

      if already_paid
        affiliate_groups[affiliate_key][:paid_amount] += affiliate_commission
      else
        affiliate_groups[affiliate_key][:pending_amount] += affiliate_commission
      end
    end

    # Convert to array and sort by sub_agent name
    affiliate_groups.values.sort_by { |group| "#{group[:affiliate].first_name} #{group[:affiliate].last_name}" }
  end

  def get_all_paid_policies
    policies = []

    # Health Insurances
    policies += HealthInsurance.where(main_agent_commission_received: true)

    # Life Insurances
    policies += LifeInsurance.where(main_agent_commission_received: true)

    # Motor Insurances
    policies += MotorInsurance.where(main_agent_commission_received: true)

    # Other Insurances (if they have the field)
    if OtherInsurance.column_names.include?('main_agent_commission_received')
      policies += OtherInsurance.where(main_agent_commission_received: true)
    end

    policies
  end

  def find_policy_by_lead_id(lead_id)
    # Search Dr WISE all insurance types
    policy = HealthInsurance.find_by(lead_id: lead_id)
    policy ||= LifeInsurance.find_by(lead_id: lead_id)
    policy ||= MotorInsurance.find_by(lead_id: lead_id)
    policy ||= OtherInsurance.find_by(lead_id: lead_id) if OtherInsurance.column_names.include?('lead_id')
    policy
  end

  def fetch_affiliate_payout_summary
    affiliates_data = []

    # Get all affiliate commission payouts
    affiliate_payouts = CommissionPayout.where(payout_to: 'affiliate')
                                       .group_by { |payout| extract_affiliate_info(payout) }

    affiliate_payouts.each do |affiliate_info, payouts|
      next if affiliate_info.nil?

      # Group payouts by lead/policy for this affiliate
      lead_commissions = payouts.map do |payout|
        policy = get_policy_from_payout(payout)
        next unless policy

        {
          lead_id: policy.id,
          policy_number: policy.policy_number,
          customer_name: policy.customer&.display_name || 'Unknown',
          commission_amount: payout.payout_amount.to_f,
          status: payout.status,
          policy_type: payout.policy_type
        }
      end.compact

      total_commission = lead_commissions.sum { |lead| lead[:commission_amount] }
      paid_amount = lead_commissions.select { |lead| lead[:status] == 'paid' }
                                   .sum { |lead| lead[:commission_amount] }
      pending_amount = total_commission - paid_amount

      affiliates_data << {
        affiliate_id: affiliate_info[:id],
        affiliate_name: affiliate_info[:name],
        affiliate_email: affiliate_info[:email],
        lead_count: lead_commissions.count,
        lead_commissions: lead_commissions,
        total_commission: total_commission,
        paid_amount: paid_amount,
        pending_amount: pending_amount,
        commission_status: pending_amount > 0 ? 'pending' : 'completed'
      }
    end

    # Sort by total commission descending
    affiliates_data.sort_by { |a| -a[:total_commission] }
  end

  def fetch_affiliate_detailed_payouts(affiliate_id)
    affiliate_payouts = CommissionPayout.where(payout_to: 'affiliate')
                                       .select do |payout|
      affiliate_info = extract_affiliate_info(payout)
      affiliate_info&.dig(:id) == affiliate_id.to_i
    end

    lead_wise_commissions = affiliate_payouts.map do |payout|
      policy = get_policy_from_payout(payout)
      next unless policy

      {
        lead_id: policy.id,
        policy_number: policy.policy_number,
        customer_name: policy.customer&.display_name || 'Unknown',
        policy_type: payout.policy_type.titleize,
        commission_amount: payout.payout_amount.to_f,
        status: payout.status,
        payout_date: payout.payout_date,
        transaction_id: payout.transaction_id,
        created_at: payout.created_at,
        notes: payout.notes
      }
    end.compact

    total_commission = lead_wise_commissions.sum { |lead| lead[:commission_amount] }
    paid_amount = lead_wise_commissions.select { |lead| lead[:status] == 'paid' }
                                      .sum { |lead| lead[:commission_amount] }
    pending_amount = total_commission - paid_amount

    {
      lead_wise_commissions: lead_wise_commissions,
      summary: {
        total_leads: lead_wise_commissions.count,
        total_commission: total_commission,
        paid_amount: paid_amount,
        pending_amount: pending_amount,
        paid_count: lead_wise_commissions.count { |lead| lead[:status] == 'paid' },
        pending_count: lead_wise_commissions.count { |lead| lead[:status] == 'pending' }
      }
    }
  end

  def extract_affiliate_info(payout)
    # For now, we'll create mock affiliate info based on payout data
    # In a real system, you'd have an Affiliate model or reference
    policy = get_policy_from_payout(payout)
    return nil unless policy

    # Generate consistent affiliate info based on customer or other criteria
    # This is a simplified approach - you might want to add actual affiliate tracking
    customer = policy.customer
    return nil unless customer

    # For demo purposes, we'll group by customer email domain or create mock affiliates
    affiliate_id = (customer.email.hash % 10).abs + 1

    {
      id: affiliate_id,
      name: "Affiliate #{affiliate_id}",
      email: "affiliate#{affiliate_id}@drwise.com"
    }
  end

  def find_affiliate_by_id(affiliate_id)
    # Mock affiliate data - replace with actual affiliate model when available
    {
      id: affiliate_id.to_i,
      name: "Affiliate #{affiliate_id}",
      email: "affiliate#{affiliate_id}@drwise.com"
    }
  end

  def get_policy_from_payout(payout)
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

  def mark_single_lead_payout(lead_id)
    mark_single_lead_payout_with_details(lead_id, "AFF_#{Time.current.to_i}", Date.current, "Affiliate payout for Lead ID: #{lead_id}")
  end

  def mark_single_lead_payout_with_details(lead_id, transaction_id, payment_date, notes)
    Rails.logger.info "Processing lead payout: lead_id=#{lead_id}, transaction_id=#{transaction_id}"

    policy = find_policy_by_lead_id(lead_id)
    unless policy
      Rails.logger.error "Policy not found for lead #{lead_id}"
      return { success: false, error: "Policy not found for lead #{lead_id}" }
    end

    # Get the actual saved affiliate commission amount
    payout = Payout.find_by(policy_type: get_policy_type(policy), policy_id: policy.id)
    affiliate_commission = payout&.affiliate_commission_amount || (policy.net_premium * 0.02)
    Rails.logger.info "Calculated commission: #{affiliate_commission} for policy #{policy.id}"

    # Get correct policy type for validation
    policy_type = get_policy_type(policy)

    # Check if already paid
    existing_payout = CommissionPayout.find_by(
      policy_type: policy_type,
      policy_id: policy.id,
      payout_to: 'affiliate'
    )

    begin
      if existing_payout
        Rails.logger.info "Updating existing payout #{existing_payout.id}"
        existing_payout.update!(
          status: 'paid',
          payout_date: payment_date || Date.current,
          transaction_id: transaction_id,
          notes: notes,
          processed_by: current_user&.email || 'system',
          processed_at: Time.current
        )
        Rails.logger.info "Successfully updated existing payout"
      else
        Rails.logger.info "Creating new payout record"
        payout = CommissionPayout.create!(
          policy_type: policy_type,
          policy_id: policy.id,
          payout_to: 'affiliate',
          payout_amount: affiliate_commission,
          payout_date: payment_date || Date.current,
          status: 'paid',
          transaction_id: transaction_id,
          payment_mode: 'bank_transfer',
          reference_number: "REF_#{lead_id}_#{Time.current.to_i}",
          notes: notes || "Affiliate payout for Lead ID: #{lead_id}",
          processed_by: current_user&.email || 'system',
          processed_at: Time.current
        )
        Rails.logger.info "Successfully created new payout: #{payout.id}"
      end
      { success: true }
    rescue => e
      Rails.logger.error "Failed to process lead #{lead_id}: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      { success: false, error: "Failed to process lead #{lead_id}: #{e.message}" }
    end
  end

  def mark_all_affiliate_payouts(affiliate_id)
    sub_agent = SubAgent.find_by(id: affiliate_id)
    return unless sub_agent

    # Find all pending affiliate payouts
    paid_policies = get_all_paid_policies
    paid_policies.each do |policy|
      next unless policy.lead_id.present?
      next unless policy.sub_agent_id == affiliate_id.to_i

      # Check if not already paid
      policy_type = get_policy_type(policy)
      existing_payout = CommissionPayout.find_by(
        policy_type: policy_type,
        policy_id: policy.id,
        payout_to: 'affiliate',
        status: 'paid'
      )
      next if existing_payout

      mark_single_lead_payout(policy.lead_id)
    end
  end

  def get_policy_type(policy)
    case policy.class.name
    when 'HealthInsurance'
      'health'
    when 'LifeInsurance'
      'life'
    when 'MotorInsurance'
      'motor'
    when 'OtherInsurance'
      'other'
    else
      'health' # fallback
    end
  end

  def generate_affiliate_invoices(affiliate_id, lead_ids, payout_type)
    begin
      invoices_created = false

      # Collect all affiliates that need invoices
      affiliates_to_process = Set.new

      case payout_type
      when 'affiliate_all', 'bulk_selection'
        # Add specific affiliate
        affiliates_to_process.add(affiliate_id.to_i) if affiliate_id.present?

        # Add affiliates from bulk selection
        if payout_type == 'bulk_selection' && params[:affiliate_ids].present?
          params[:affiliate_ids].each do |aff_id|
            affiliates_to_process.add(aff_id.to_i)
          end
        end

      when 'lead_single', 'lead_multiple', 'bulk_modal_selection'
        # Find affiliates from the leads
        lead_ids.each do |lead_id|
          policy = find_policy_by_lead_id(lead_id)
          if policy && policy.respond_to?(:sub_agent_id) && policy.sub_agent_id.present?
            affiliates_to_process.add(policy.sub_agent_id)
          end
        end

      when 'quick_all_pending'
        # Find all affiliates that had recent payments
        CommissionPayout.where(payout_to: 'affiliate', status: 'paid', updated_at: 1.minute.ago..Time.current).each do |payout|
          policy = get_policy_from_commission_payout(payout)
          if policy && policy.respond_to?(:sub_agent_id) && policy.sub_agent_id.present?
            affiliates_to_process.add(policy.sub_agent_id)
          end
        end
      end

      # Generate/update one invoice per affiliate
      affiliates_to_process.each do |aff_id|
        invoice = generate_or_update_affiliate_invoice(aff_id)
        invoices_created = true if invoice
      end

      return invoices_created

    rescue => e
      Rails.logger.error "Invoice generation failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      return false
    end
  end

  def generate_single_affiliate_invoice(affiliate_id)
    sub_agent = SubAgent.find_by(id: affiliate_id)
    return unless sub_agent

    # Get all paid commission payouts for this affiliate
    paid_payouts = CommissionPayout.where(payout_to: 'affiliate', status: 'paid')
                                   .select do |payout|
      policy = get_policy_from_commission_payout(payout)
      policy && policy.respond_to?(:sub_agent_id) && policy.sub_agent_id == affiliate_id.to_i
    end

    return if paid_payouts.empty?

    # Calculate total commission from paid payouts
    total_commission = paid_payouts.sum(&:payout_amount)
    return if total_commission <= 0

    # Generate unique invoice number
    invoice_number = generate_invoice_number

    # Check if invoice already exists with this invoice number
    existing_invoice = Invoice.find_by(invoice_number: invoice_number)

    # If exists, generate a new unique number
    while existing_invoice
      invoice_number = generate_invoice_number
      existing_invoice = Invoice.find_by(invoice_number: invoice_number)
    end

    # Create invoice
    begin
      invoice = Invoice.create!(
        invoice_number: invoice_number,
        payout_type: 'affiliate',
        payout_id: affiliate_id,
        total_amount: total_commission,
        status: 'paid', # Mark as paid since payouts are already processed
        invoice_date: Date.current,
        due_date: Date.current,
        paid_at: Time.current # Set paid_at since it's already paid
      )

      Rails.logger.info "Generated invoice #{invoice.invoice_number} for sub_agent #{sub_agent.first_name} #{sub_agent.last_name} (#{sub_agent.id})"
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to create invoice for affiliate #{affiliate_id}: #{e.message}"
    rescue => e
      Rails.logger.error "Unexpected error creating invoice for affiliate #{affiliate_id}: #{e.message}"
    end
  end

  def generate_invoices_for_leads(lead_ids)
    invoices = []
    # Group leads by affiliate
    affiliate_groups = {}

    lead_ids.each do |lead_id|
      policy = find_policy_by_lead_id(lead_id)
      next unless policy
      next unless policy.respond_to?(:sub_agent_id) && policy.sub_agent_id.present?

      affiliate_id = policy.sub_agent_id
      affiliate_groups[affiliate_id] ||= []
      affiliate_groups[affiliate_id] << lead_id
    end

    # Generate invoice for each affiliate group
    affiliate_groups.each do |affiliate_id, group_lead_ids|
      invoice = generate_single_affiliate_invoice_for_leads(affiliate_id, group_lead_ids)
      invoices << invoice if invoice
    end

    invoices
  end

  def generate_single_affiliate_invoice_for_leads(affiliate_id, lead_ids)
    sub_agent = SubAgent.find_by(id: affiliate_id)
    return unless sub_agent

    # Calculate total commission for these specific leads
    total_commission = 0
    policies_processed = []

    lead_ids.each do |lead_id|
      policy = find_policy_by_lead_id(lead_id)
      next unless policy

      # Get the commission payout for this policy
      policy_type = get_policy_type(policy)
      payout = CommissionPayout.find_by(
        policy_type: policy_type,
        policy_id: policy.id,
        payout_to: 'affiliate',
        status: 'paid'
      )

      if payout
        total_commission += payout.payout_amount.to_f
        policies_processed << policy.policy_number
      end
    end

    return if total_commission <= 0

    # Generate unique invoice number
    invoice_number = generate_invoice_number

    # Create invoice
    begin
      invoice = Invoice.create!(
        invoice_number: invoice_number,
        payout_type: 'affiliate',
        payout_id: affiliate_id,
        total_amount: total_commission,
        status: 'paid',
        invoice_date: Date.current,
        due_date: Date.current,
        paid_at: Time.current,
        recipient_name: "#{sub_agent.first_name} #{sub_agent.last_name}",
        recipient_email: sub_agent.email,
        notes: "Affiliate commission for policies: #{policies_processed.join(', ')}"
      )

      Rails.logger.info "Generated invoice #{invoice.invoice_number} for sub_agent #{sub_agent.first_name} #{sub_agent.last_name} (#{sub_agent.id})"
      invoice
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to create invoice for affiliate #{affiliate_id}: #{e.message}"
      nil
    rescue => e
      Rails.logger.error "Unexpected error creating invoice for affiliate #{affiliate_id}: #{e.message}"
      nil
    end
  end

  def generate_single_affiliate_invoice_for_recent_payments(affiliate_id)
    sub_agent = SubAgent.find_by(id: affiliate_id)
    return unless sub_agent

    # Get recently paid commission payouts for this affiliate (within last minute)
    recent_payouts = CommissionPayout.where(
      payout_to: 'affiliate',
      status: 'paid',
      updated_at: 1.minute.ago..Time.current
    ).select do |payout|
      policy = get_policy_from_commission_payout(payout)
      policy && policy.respond_to?(:sub_agent_id) && policy.sub_agent_id == affiliate_id.to_i
    end

    return if recent_payouts.empty?

    # Calculate total commission
    total_commission = recent_payouts.sum(&:payout_amount)
    return if total_commission <= 0

    # Collect policy numbers
    policies_processed = recent_payouts.map do |payout|
      policy = get_policy_from_commission_payout(payout)
      policy&.policy_number
    end.compact

    # Generate unique invoice number
    invoice_number = generate_invoice_number

    # Create invoice
    begin
      invoice = Invoice.create!(
        invoice_number: invoice_number,
        payout_type: 'affiliate',
        payout_id: affiliate_id,
        total_amount: total_commission,
        status: 'paid',
        invoice_date: Date.current,
        due_date: Date.current,
        paid_at: Time.current,
        recipient_name: "#{sub_agent.first_name} #{sub_agent.last_name}",
        recipient_email: sub_agent.email,
        notes: "Affiliate commission for policies: #{policies_processed.join(', ')}"
      )

      Rails.logger.info "Generated invoice #{invoice.invoice_number} for sub_agent #{sub_agent.first_name} #{sub_agent.last_name} (#{sub_agent.id})"
      invoice
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to create invoice for affiliate #{affiliate_id}: #{e.message}"
      nil
    rescue => e
      Rails.logger.error "Unexpected error creating invoice for affiliate #{affiliate_id}: #{e.message}"
      nil
    end
  end

  def calculate_affiliate_total_commission(affiliate_id)
    total_commission = 0

    # Get all paid commission payouts for this affiliate
    paid_payouts = CommissionPayout.where(payout_to: 'affiliate', status: 'paid')
                                   .select do |payout|
      policy = get_policy_from_commission_payout(payout)
      policy && policy.respond_to?(:sub_agent_id) && policy.sub_agent_id == affiliate_id.to_i
    end

    # Sum up the commission amounts from paid payouts
    paid_payouts.each do |payout|
      total_commission += payout.payout_amount.to_f
    end

    total_commission
  end

  def generate_invoice_number
    "INV-AFF-#{Date.current.strftime('%Y%m%d')}-#{rand(10000..99999)}"
  end

  def generate_or_update_affiliate_invoice(affiliate_id)
    sub_agent = SubAgent.find_by(id: affiliate_id)
    return unless sub_agent

    # Check if there's already an invoice for this affiliate this month
    current_month_start = Date.current.beginning_of_month
    current_month_end = Date.current.end_of_month
    existing_invoice = Invoice.where(
      payout_type: 'affiliate',
      payout_id: affiliate_id,
      invoice_date: current_month_start..current_month_end
    ).first

    # Get all paid commission payouts for this affiliate in the current month
    paid_payouts = CommissionPayout.where(payout_to: 'affiliate', status: 'paid')
                                   .where('payout_date BETWEEN ? AND ? OR (payout_date IS NULL AND updated_at BETWEEN ? AND ?)',
                                          current_month_start, current_month_end,
                                          current_month_start.to_time, (current_month_end + 1.day).to_time)
                                   .select do |payout|
      policy = get_policy_from_commission_payout(payout)
      policy && policy.respond_to?(:sub_agent_id) && policy.sub_agent_id == affiliate_id.to_i
    end

    return if paid_payouts.empty?

    # Calculate total commission from paid payouts in current month
    total_commission = paid_payouts.sum(&:payout_amount)
    return if total_commission <= 0

    # Collect policy numbers for the notes
    policies_processed = paid_payouts.map do |payout|
      policy = get_policy_from_commission_payout(payout)
      policy&.policy_number
    end.compact.uniq

    begin
      if existing_invoice
        # Update existing invoice with new total (consolidating all payouts for the month)
        existing_invoice.update!(
          total_amount: total_commission,
          notes: "Affiliate commission for #{paid_payouts.count} policies in #{Date.current.strftime('%B %Y')}: #{policies_processed.join(', ')}",
          updated_at: Time.current
        )
        Rails.logger.info "Updated existing monthly invoice #{existing_invoice.invoice_number} for affiliate #{sub_agent.first_name} #{sub_agent.last_name} (#{sub_agent.id})"
        existing_invoice
      else
        # Create new monthly consolidated invoice
        invoice_number = generate_unique_monthly_invoice_number(affiliate_id)

        invoice = Invoice.create!(
          invoice_number: invoice_number,
          payout_type: 'affiliate',
          payout_id: affiliate_id,
          total_amount: total_commission,
          status: 'paid',
          invoice_date: Date.current,
          due_date: Date.current,
          paid_at: Time.current,
          recipient_name: "#{sub_agent.first_name} #{sub_agent.last_name}",
          recipient_email: sub_agent.email,
          notes: "Monthly affiliate commission for #{paid_payouts.count} policies in #{Date.current.strftime('%B %Y')}: #{policies_processed.join(', ')}"
        )

        Rails.logger.info "Generated monthly consolidated invoice #{invoice.invoice_number} for affiliate #{sub_agent.first_name} #{sub_agent.last_name} (#{sub_agent.id})"
        invoice
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to create/update monthly invoice for affiliate #{affiliate_id}: #{e.message}"
      nil
    rescue => e
      Rails.logger.error "Unexpected error creating/updating monthly invoice for affiliate #{affiliate_id}: #{e.message}"
      nil
    end
  end

  def generate_unique_monthly_invoice_number(affiliate_id)
    # Generate a deterministic invoice number based on affiliate and month
    year_month = Date.current.strftime('%Y%m')
    base_number = "INV-AFF-#{year_month}-#{affiliate_id.to_s.rjust(5, '0')}"

    # Check if this exact number exists
    counter = 1
    invoice_number = base_number

    while Invoice.exists?(invoice_number: invoice_number)
      invoice_number = "#{base_number}-#{counter}"
      counter += 1
    end

    invoice_number
  end

  def generate_unique_invoice_number(affiliate_id)
    # Generate a deterministic invoice number based on affiliate and date
    date_str = Date.current.strftime('%Y%m%d')
    base_number = "INV-AFF-#{date_str}-#{affiliate_id.to_s.rjust(5, '0')}"

    # Check if this exact number exists
    counter = 1
    invoice_number = base_number

    while Invoice.exists?(invoice_number: invoice_number)
      invoice_number = "#{base_number}-#{counter}"
      counter += 1
    end

    invoice_number
  end

end