require 'ostruct'

class Admin::DistributorPayoutsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin_access

  def index
    @distributor_payouts = calculate_distributor_payouts
    @total_distributors = @distributor_payouts.count
    @total_pending_amount = @distributor_payouts.sum { |d| d[:pending_amount] }
    @total_paid_amount = @distributor_payouts.sum { |d| d[:paid_amount] }
    @total_commission_earned = @distributor_payouts.sum { |d| d[:total_amount] }
  end

  def mark_as_paid
    begin
      distributor_id = params[:distributor_id]
      lead_ids = params[:lead_ids] || []
      payout_type = params[:payout_type] || 'multiple_leads'

      Rails.logger.info "=== DISTRIBUTOR PAYOUT DEBUG ==="
      Rails.logger.info "distributor_id: #{distributor_id}"
      Rails.logger.info "lead_ids: #{lead_ids.inspect}"
      Rails.logger.info "payout_type: #{payout_type}"

      success_count = 0
      errors = []

      case payout_type
      when 'distributor_all'
        # Mark all pending payouts for this distributor as paid
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
          # Fallback: find all unpaid leads for this distributor
          mark_all_distributor_payouts(distributor_id)
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
        distributor_ids = params[:distributor_ids] || []

        # Process selected distributors (all their pending leads)
        distributor_ids.each do |dist_id|
          mark_all_distributor_payouts(dist_id)
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
        # Handle quick payout for all pending distributor payouts
        transaction_id = params[:transaction_id]
        payment_date = params[:payment_date] || Date.current
        notes = params[:notes] || "Quick batch payout for all pending distributors"

        # Get all pending distributor payouts
        pending_payouts = calculate_distributor_payouts.select { |d| d[:pending_amount] > 0 }

        pending_payouts.each do |distributor_data|
          unpaid_leads = distributor_data[:leads].select { |l| !l[:paid] }
          unpaid_leads.each do |lead_data|
            result = mark_single_lead_payout_with_details(lead_data[:lead].lead_id, transaction_id, payment_date, notes)
            success_count += 1 if result[:success]
            errors << result[:error] if result[:error]
          end
        end
      else
        # Default: mark specific distributor's leads as paid
        lead_ids.each do |lead_id|
          result = mark_single_lead_payout(lead_id)
          success_count += 1 if result[:success]
          errors << result[:error] if result[:error]
        end
      end

      if errors.any?
        redirect_to admin_distributor_payouts_path, alert: "Some payouts failed: #{errors.join(', ')}"
      else
        # Generate ambassador invoices after successful payouts.
        # All payouts in this flow are ambassador commissions — no distributor invoice is generated.
        invoice_errors = []

        begin
          generate_ambassador_invoices(distributor_id, lead_ids, payout_type)
        rescue => e
          Rails.logger.error "Ambassador invoice generation failed: #{e.message}"
          Rails.logger.error e.backtrace.first(5).join("\n")
          invoice_errors << "Ambassador invoice generation failed: #{e.message}"
        end

        if invoice_errors.any?
          redirect_to admin_distributor_payouts_path, alert: "#{success_count} distributor payout(s) marked as paid successfully! However, invoice generation had issues: #{invoice_errors.join('; ')}"
        else
          redirect_to admin_distributor_payouts_path, notice: "#{success_count} distributor payout(s) marked as paid successfully! Invoices have been generated."
        end
      end

    rescue StandardError => e
      redirect_to admin_distributor_payouts_path, alert: "Error processing payouts: #{e.message}"
    end
  end

  def show
    @distributor_id = params[:id]
    @distributor = find_distributor_by_id(@distributor_id)

    unless @distributor
      redirect_to admin_distributor_payouts_path, alert: 'Distributor not found'
      return
    end

    @distributor_details = fetch_distributor_detailed_payouts(@distributor_id)
    @lead_wise_commissions = @distributor_details[:lead_wise_commissions]
    @summary = @distributor_details[:summary]
  end

  def unpaid_data
    unpaid_distributors = calculate_distributor_payouts.select { |d| d[:pending_amount] > 0 }

    render json: {
      success: true,
      data: unpaid_distributors.map do |distributor_data|
        {
          distributor: {
            id: distributor_data[:distributor].id,
            name: distributor_data[:distributor].display_name,
            email: distributor_data[:distributor].email
          },
          leads: distributor_data[:leads].reject { |l| l[:paid] }.map do |lead_data|
            {
              id: lead_data[:lead].lead_id,
              policy_id: lead_data[:policy].id,
              commission: lead_data[:commission].round(2),
              policy_number: lead_data[:policy].policy_number,
              customer_name: lead_data[:policy].customer&.display_name || 'Unknown'
            }
          end,
          total_pending: distributor_data[:pending_amount].round(2)
        }
      end
    }
  rescue StandardError => e
    render json: { success: false, message: e.message }
  end

  private

  def calculate_distributor_payouts
    payouts = []

    # Get all commission payouts for ambassadors (distributors) directly - similar to affiliate logic
    ambassador_commission_payouts = CommissionPayout.where(payout_to: 'ambassador').includes(:payout)

    # Group by distributor
    distributor_groups = {}

    ambassador_commission_payouts.each do |commission_payout|
      # Get policy from commission payout
      policy = get_policy_from_commission_payout(commission_payout)
      next unless policy

      # Skip if main agent commission not received - same logic as affiliates
      next unless policy.respond_to?(:main_agent_commission_received) && policy.main_agent_commission_received

      # Get distributor from the policy's distributor_id field
      distributor = Distributor.find_by(id: policy.distributor_id) if policy.respond_to?(:distributor_id) && policy.distributor_id.present?
      next unless distributor

      # Get or create lead if needed
      lead = nil
      if commission_payout.lead_id.present?
        lead = Lead.find_by(lead_id: commission_payout.lead_id)
      end

      # Fallback: try to find lead by policy lead_id
      if lead.nil? && policy.respond_to?(:lead_id) && policy.lead_id.present?
        lead = Lead.find_by(lead_id: policy.lead_id)
      end

      # If no lead found, create a virtual lead object for display purposes (same as affiliates)
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

      distributor_commission = commission_payout.payout_amount.to_f

      # Check if already paid
      already_paid = commission_payout.status == 'paid'

      distributor_key = distributor.id

      distributor_groups[distributor_key] ||= {
        distributor: distributor,
        leads: [],
        total_amount: 0,
        paid_amount: 0,
        pending_amount: 0
      }

      lead_data = {
        lead: lead,
        policy: policy,
        commission: distributor_commission,
        paid: already_paid
      }

      distributor_groups[distributor_key][:leads] << lead_data
      distributor_groups[distributor_key][:total_amount] += distributor_commission

      if already_paid
        distributor_groups[distributor_key][:paid_amount] += distributor_commission
      else
        distributor_groups[distributor_key][:pending_amount] += distributor_commission
      end
    end

    # Convert to array and sort by distributor name
    distributor_groups.values.sort_by { |group| group[:distributor].display_name }
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

  def fetch_distributor_detailed_payouts(distributor_id)
    distributor_payouts = DistributorPayout.where(distributor_id: distributor_id)

    lead_wise_commissions = distributor_payouts.map do |payout|
      policy = payout.policy
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

  def find_distributor_by_id(distributor_id)
    Distributor.find_by(id: distributor_id)
  end

  def mark_single_lead_payout(lead_id)
    mark_single_lead_payout_with_details(lead_id, "DIST_#{Time.current.to_i}", Date.current, "Distributor payout for Lead ID: #{lead_id}")
  end

  def mark_single_lead_payout_with_details(lead_id, transaction_id, payment_date, notes)
    Rails.logger.info "Processing lead payout: lead_id=#{lead_id}, transaction_id=#{transaction_id}"

    policy = find_policy_by_lead_id(lead_id)
    unless policy
      Rails.logger.error "Policy not found for lead #{lead_id}"
      return { success: false, error: "Policy not found for lead #{lead_id}" }
    end

    # Find distributor from policy
    distributor = Distributor.find_by(id: policy.distributor_id) if policy.respond_to?(:distributor_id) && policy.distributor_id.present?
    unless distributor
      Rails.logger.error "Distributor not found for policy #{policy.id}"
      return { success: false, error: "Distributor not found for policy #{policy.id}" }
    end

    # Get the actual saved ambassador commission amount (distributors = ambassadors)
    payout = Payout.find_by(policy_type: get_policy_type(policy), policy_id: policy.id)
    distributor_commission = payout&.ambassador_commission_amount || (policy.net_premium * 0.03)
    Rails.logger.info "Calculated commission: #{distributor_commission} for policy #{policy.id}"

    # Get correct policy type for validation
    policy_type = get_policy_type(policy)

    # Check if already paid
    existing_payout = DistributorPayout.find_by(
      policy_type: policy_type,
      policy_id: policy.id,
      distributor_id: distributor.id
    )

    begin
      if existing_payout
        Rails.logger.info "Updating existing payout #{existing_payout.id}"
        existing_payout.mark_as_paid!(
          transaction_id: transaction_id,
          payment_date: payment_date || Date.current,
          notes: notes,
          processed_by: current_user&.email || 'system'
        )
        Rails.logger.info "Successfully updated existing payout"

        # Also update the corresponding CommissionPayout for ambassador/distributor
        commission_payout = CommissionPayout.find_by(
          policy_type: policy_type,
          policy_id: policy.id,
          payout_to: 'ambassador'
        )

        if commission_payout
          commission_payout.update!(
            status: 'paid',
            payout_date: payment_date || Date.current,
            transaction_id: transaction_id,
            notes: notes || "Distributor/Ambassador payout processed",
            processed_by: current_user&.email || 'system',
            processed_at: Time.current
          )
          Rails.logger.info "Updated CommissionPayout #{commission_payout.id} status to paid for ambassador (existing payout case)"

          # Create ambassador commission display record for tracking
          create_ambassador_commission_record(policy, commission_payout, transaction_id, payment_date, notes)
        else
          Rails.logger.warn "No CommissionPayout found for policy #{policy.id} (#{policy_type}) ambassador (existing payout case)"
        end
      else
        Rails.logger.info "Creating new payout record"
        distributor_payout = DistributorPayout.create!(
          distributor_id: distributor.id,
          policy_type: policy_type,
          policy_id: policy.id,
          payout_amount: distributor_commission,
          payout_date: payment_date || Date.current,
          status: 'paid',
          transaction_id: transaction_id,
          payment_mode: 'bank_transfer',
          reference_number: "REF_#{lead_id}_#{Time.current.to_i}",
          notes: notes || "Distributor payout for Lead ID: #{lead_id}",
          processed_by: current_user&.email || 'system',
          processed_at: Time.current
        )
        Rails.logger.info "Successfully created new payout: #{distributor_payout.id}"

        # Also update the corresponding CommissionPayout for ambassador/distributor
        commission_payout = CommissionPayout.find_by(
          policy_type: policy_type,
          policy_id: policy.id,
          payout_to: 'ambassador'
        )

        if commission_payout
          commission_payout.update!(
            status: 'paid',
            payout_date: payment_date || Date.current,
            transaction_id: transaction_id,
            notes: notes || "Distributor/Ambassador payout processed",
            processed_by: current_user&.email || 'system',
            processed_at: Time.current
          )
          Rails.logger.info "Updated CommissionPayout #{commission_payout.id} status to paid for ambassador"

          # Create ambassador commission display record for tracking
          create_ambassador_commission_record(policy, commission_payout, transaction_id, payment_date, notes)
        else
          Rails.logger.warn "No CommissionPayout found for policy #{policy.id} (#{policy_type}) ambassador"
        end
      end
      { success: true }
    rescue => e
      Rails.logger.error "Failed to process lead #{lead_id}: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      { success: false, error: "Failed to process lead #{lead_id}: #{e.message}" }
    end
  end

  def mark_all_distributor_payouts(distributor_id)
    distributor = Distributor.find_by(id: distributor_id)
    return unless distributor

    # Find all pending distributor payouts
    paid_policies = get_all_paid_policies
    paid_policies.each do |policy|
      next unless policy.lead_id.present?
      next unless policy.distributor_id == distributor_id.to_i

      # Check if not already paid
      policy_type = get_policy_type(policy)
      existing_payout = DistributorPayout.find_by(
        policy_type: policy_type,
        policy_id: policy.id,
        distributor_id: distributor_id,
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

  def generate_distributor_invoices(distributor_id, lead_ids, payout_type)
    Rails.logger.info "=== GENERATING DISTRIBUTOR INVOICES ==="
    Rails.logger.info "distributor_id: #{distributor_id}, lead_ids: #{lead_ids.inspect}, payout_type: #{payout_type}"

    begin
      case payout_type
      when 'distributor_all', 'bulk_selection'
        # Generate invoice for specific distributor
        if distributor_id.present?
          Rails.logger.info "Generating invoice for distributor #{distributor_id}"
          result = generate_single_distributor_invoice(distributor_id)
          Rails.logger.info "Distributor invoice result: #{result}"
        end

        # Generate invoices for distributor_ids if it's bulk selection
        if payout_type == 'bulk_selection' && params[:distributor_ids].present?
          params[:distributor_ids].each do |dist_id|
            Rails.logger.info "Generating invoice for distributor #{dist_id} (bulk)"
            generate_single_distributor_invoice(dist_id)
          end
        end

      when 'lead_single', 'lead_multiple', 'bulk_modal_selection'
        # Generate invoices by grouping leads by distributor
        Rails.logger.info "Generating invoices for leads: #{lead_ids.inspect}"
        generate_invoices_for_distributor_leads(lead_ids)

      when 'quick_all_pending'
        # Generate invoices for all distributors with pending payouts
        pending_payouts = calculate_distributor_payouts.select { |d| d[:pending_amount] > 0 }
        Rails.logger.info "Generating invoices for #{pending_payouts.count} distributors with pending payouts"
        pending_payouts.each do |distributor_data|
          generate_single_distributor_invoice(distributor_data[:distributor].id)
        end
      else
        Rails.logger.info "Unknown payout_type for distributor invoice: #{payout_type}"
      end

    rescue => e
      Rails.logger.error "Distributor invoice generation failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
    Rails.logger.info "=== DISTRIBUTOR INVOICE GENERATION COMPLETED ==="
  end

  def generate_single_distributor_invoice(distributor_id)
    Rails.logger.info "=== GENERATING SINGLE DISTRIBUTOR INVOICE ==="
    Rails.logger.info "Looking for distributor with ID: #{distributor_id}"

    # Return early if distributor_id is nil or invalid
    return false if distributor_id.blank?

    distributor = Distributor.find_by(id: distributor_id)
    unless distributor
      Rails.logger.error "Distributor not found for ID: #{distributor_id}"
      return false
    end

    Rails.logger.info "Found distributor: #{distributor.display_name} (#{distributor.id})"

    # Use the payout date or fall back to current date for month calculation
    # This ensures invoices are generated for the correct period
    invoice_month = Date.current
    current_month_start = invoice_month.beginning_of_month
    current_month_end = invoice_month.end_of_month

    # Check if invoice already exists for this distributor this month
    existing_invoice = Invoice.find_by(
      payout_type: 'distributor',
      payout_id: distributor_id,
      invoice_date: current_month_start..current_month_end
    )

    # Get all paid distributor payouts for this month
    paid_payouts = DistributorPayout.where(distributor_id: distributor_id, status: 'paid')
                                    .where('payout_date BETWEEN ? AND ? OR (payout_date IS NULL AND updated_at BETWEEN ? AND ?)',
                                           current_month_start, current_month_end,
                                           current_month_start.to_time, (current_month_end + 1.day).to_time)

    total_commission = paid_payouts.sum(&:payout_amount).to_f
    Rails.logger.info "Calculated monthly commission: #{total_commission} for #{paid_payouts.count} payouts"

    if total_commission <= 0
      Rails.logger.info "No commission to invoice for distributor #{distributor_id} this month"
      return false
    end

    begin
      if existing_invoice
        # Update existing invoice with current month's total
        existing_invoice.update!(
          total_amount: total_commission,
          notes: "Monthly distributor commission for #{paid_payouts.count} payouts in #{invoice_month.strftime('%B %Y')}",
          recipient_name: distributor.display_name,  # Update in case name changed
          recipient_email: distributor.email,  # Update in case email changed
          updated_at: Time.current
        )
        Rails.logger.info "Updated existing monthly invoice #{existing_invoice.invoice_number} for distributor #{distributor.display_name} (#{distributor.id})"
        return true
      else
        # Create new monthly invoice
        invoice = Invoice.create!(
          invoice_number: generate_monthly_distributor_invoice_number(distributor_id),
          payout_type: 'distributor',
          payout_id: distributor_id,
          total_amount: total_commission,
          status: 'paid',
          invoice_date: invoice_month,
          due_date: invoice_month,
          paid_at: Time.current,
          recipient_name: distributor.display_name,
          recipient_email: distributor.email || 'no-email@example.com',  # Handle missing email
          notes: "Monthly distributor commission for #{paid_payouts.count} payouts in #{invoice_month.strftime('%B %Y')}"
        )

        Rails.logger.info "✅ Generated monthly invoice #{invoice.invoice_number} for distributor #{distributor.display_name} (#{distributor.id})"
        Rails.logger.info "   Amount: Rs. #{total_commission}, Payouts: #{paid_payouts.count}"
        return true
      end
    rescue => e
      Rails.logger.error "❌ Failed to create/update distributor invoice: #{e.message}"
      Rails.logger.error "   Distributor: #{distributor.display_name} (#{distributor_id})"
      Rails.logger.error "   Total Commission: #{total_commission}"
      Rails.logger.error e.backtrace.first(5).join("\n")

      # Re-raise the error so it can be caught by the calling method
      raise e
    end
  end

  def generate_invoices_for_distributor_leads(lead_ids)
    # Group leads by distributor
    distributor_groups = {}

    lead_ids.each do |lead_id|
      policy = find_policy_by_lead_id(lead_id)
      next unless policy
      next unless policy.respond_to?(:distributor_id) && policy.distributor_id.present?

      distributor_id = policy.distributor_id
      distributor_groups[distributor_id] ||= []
      distributor_groups[distributor_id] << lead_id
    end

    # Generate invoice for each distributor group
    distributor_groups.each do |distributor_id, group_lead_ids|
      generate_single_distributor_invoice(distributor_id)
    end
  end

  def calculate_distributor_total_commission(distributor_id)
    total_commission = 0

    # Get all policies for this distributor where main agent commission is received
    paid_policies = get_all_paid_policies.select do |policy|
      policy.respond_to?(:distributor_id) && policy.distributor_id == distributor_id.to_i
    end

    paid_policies.each do |policy|
      # Get commission amount
      payout = Payout.find_by(policy_type: get_policy_type(policy), policy_id: policy.id)
      commission = payout&.affiliate_commission_amount || (policy.net_premium * 0.05)
      total_commission += commission
    end

    total_commission
  end

  def generate_monthly_distributor_invoice_number(distributor_id)
    # Generate a deterministic invoice number based on distributor and month
    year_month = Date.current.strftime('%Y%m')
    base_number = "INV-DIST-#{year_month}-#{distributor_id.to_s.rjust(5, '0')}"

    # Check if this exact number exists
    counter = 1
    invoice_number = base_number

    while Invoice.exists?(invoice_number: invoice_number)
      invoice_number = "#{base_number}-#{counter}"
      counter += 1
    end

    invoice_number
  end

  def generate_distributor_invoice_number
    "INV-DIST-#{Date.current.strftime('%Y%m%d')}-#{rand(10000..99999)}"
  end

  def create_ambassador_commission_record(policy, commission_payout, transaction_id, payment_date, notes)
    # Find the distributor for this policy
    distributor = Distributor.find_by(id: policy.distributor_id) if policy.respond_to?(:distributor_id) && policy.distributor_id.present?
    return unless distributor

    # Create a commission tracking record specifically for ambassador payouts
    # This helps show the commission flow: main agent -> distributor (ambassador)
    begin
      # Check if record already exists
      existing_record = CommissionPayout.find_by(
        policy_type: commission_payout.policy_type,
        policy_id: policy.id,
        payout_to: 'ambassador_display',
        lead_id: commission_payout.lead_id
      )

      unless existing_record
        CommissionPayout.create!(
          policy_type: commission_payout.policy_type,
          policy_id: policy.id,
          status: 'paid',
          payout_date: payment_date || Date.current,
          processed_by: current_user&.email || 'system',
          processed_at: Time.current,
          payout_to: 'ambassador_display', # Special type to track ambassador commission flow
          payout_amount: commission_payout.payout_amount,
          lead_id: commission_payout.lead_id,
          transaction_id: transaction_id,
          notes: "#{notes} | Ambassador commission paid to distributor: #{distributor.display_name}",
          reference_number: "AMB_#{commission_payout.lead_id}_#{Time.current.to_i}"
        )
        Rails.logger.info "Created ambassador commission display record for policy #{policy.id}"
      end
    rescue => e
      Rails.logger.error "Failed to create ambassador commission record: #{e.message}"
    end
  end

  def generate_ambassador_invoices(distributor_id, lead_ids, payout_type)
    begin
      case payout_type
      when 'distributor_all', 'bulk_selection'
        # Generate ambassador invoice for specific distributor
        if distributor_id.present?
          generate_single_ambassador_invoice(distributor_id)
        end

        # Generate invoices for distributor_ids if it's bulk selection
        if payout_type == 'bulk_selection' && params[:distributor_ids].present?
          params[:distributor_ids].each do |dist_id|
            generate_single_ambassador_invoice(dist_id)
          end
        end

      when 'lead_single', 'lead_multiple', 'bulk_modal_selection'
        # Generate ambassador invoices by grouping leads by distributor
        generate_ambassador_invoices_for_leads(lead_ids)

      when 'quick_all_pending'
        # Generate ambassador invoices for all distributors with pending payouts
        pending_payouts = calculate_distributor_payouts.select { |d| d[:pending_amount] > 0 }
        pending_payouts.each do |distributor_data|
          generate_single_ambassador_invoice(distributor_data[:distributor].id)
        end
      end

    rescue => e
      Rails.logger.error "Ambassador invoice generation failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

  def generate_single_ambassador_invoice(distributor_id)
    Rails.logger.info "=== GENERATING SINGLE AMBASSADOR INVOICE ==="
    Rails.logger.info "Looking for distributor with ID: #{distributor_id}"

    # Return early if distributor_id is nil or invalid
    return false if distributor_id.blank?

    distributor = Distributor.find_by(id: distributor_id)
    unless distributor
      Rails.logger.error "Distributor not found for ID: #{distributor_id}"
      return false
    end

    Rails.logger.info "Found distributor: #{distributor.display_name} (#{distributor.id})"

    # Use consistent month calculation
    invoice_month = Date.current
    current_month_start = invoice_month.beginning_of_month
    current_month_end = invoice_month.end_of_month

    # Check if invoice already exists for this distributor this month
    existing_invoice = Invoice.find_by(
      payout_type: 'ambassador',
      payout_id: distributor_id,
      invoice_date: current_month_start..current_month_end
    )

    # Get all ambassador commission payouts for this distributor in current month
    ambassador_payouts = CommissionPayout.where(payout_to: 'ambassador', status: 'paid')
                                          .where('payout_date BETWEEN ? AND ? OR (payout_date IS NULL AND updated_at BETWEEN ? AND ?)',
                                                 current_month_start, current_month_end,
                                                 current_month_start.to_time, (current_month_end + 1.day).to_time)
                                          .select do |payout|
      policy = get_policy_from_commission_payout(payout)
      policy&.respond_to?(:distributor_id) && policy.distributor_id == distributor_id.to_i
    end

    if ambassador_payouts.empty?
      Rails.logger.info "No ambassador payouts found for distributor #{distributor_id} this month"
      return false
    end

    total_amount = ambassador_payouts.sum(&:payout_amount).to_f
    Rails.logger.info "Calculated monthly ambassador commission: #{total_amount} for #{ambassador_payouts.count} payouts"

    if total_amount <= 0
      Rails.logger.info "No ambassador commission to invoice for distributor #{distributor_id} this month"
      return false
    end

    begin
      if existing_invoice
        # Update existing monthly invoice
        existing_invoice.update!(
          total_amount: total_amount,
          notes: "Monthly ambassador commission for #{ambassador_payouts.count} payouts in #{invoice_month.strftime('%B %Y')}",
          recipient_name: distributor.display_name,  # Update in case name changed
          recipient_email: distributor.email,  # Update in case email changed
          updated_at: Time.current
        )
        Rails.logger.info "Updated existing monthly ambassador invoice #{existing_invoice.invoice_number} for distributor #{distributor.display_name} (#{distributor.id})"
        return true
      else
        # Create new monthly invoice
        invoice = Invoice.create!(
          invoice_number: generate_monthly_ambassador_invoice_number(distributor_id),
          payout_type: 'ambassador',
          payout_id: distributor_id,
          total_amount: total_amount,
          status: 'paid',
          invoice_date: invoice_month,
          due_date: invoice_month,
          paid_at: Time.current,
          recipient_name: distributor.display_name,
          recipient_email: distributor.email || 'no-email@example.com',  # Handle missing email
          notes: "Monthly ambassador commission for #{ambassador_payouts.count} payouts in #{invoice_month.strftime('%B %Y')}"
        )

        Rails.logger.info "✅ Generated monthly ambassador invoice #{invoice.invoice_number} for distributor #{distributor.display_name} (#{distributor.id})"
        Rails.logger.info "   Amount: Rs. #{total_amount}, Payouts: #{ambassador_payouts.count}"
        return true
      end
    rescue => e
      Rails.logger.error "❌ Failed to create/update ambassador invoice: #{e.message}"
      Rails.logger.error "   Distributor: #{distributor.display_name} (#{distributor_id})"
      Rails.logger.error "   Total Amount: #{total_amount}"
      Rails.logger.error e.backtrace.first(5).join("\n")

      # Re-raise the error so it can be caught by the calling method
      raise e
    end
  end

  def generate_ambassador_invoices_for_leads(lead_ids)
    # Group leads by distributor
    distributor_groups = {}

    lead_ids.each do |lead_id|
      policy = find_policy_by_lead_id(lead_id)
      next unless policy
      next unless policy.respond_to?(:distributor_id) && policy.distributor_id.present?

      distributor_id = policy.distributor_id
      distributor_groups[distributor_id] ||= []
      distributor_groups[distributor_id] << lead_id
    end

    # Generate ambassador invoice for each distributor group
    distributor_groups.each do |distributor_id, group_lead_ids|
      generate_single_ambassador_invoice(distributor_id)
    end
  end

  def generate_monthly_ambassador_invoice_number(distributor_id)
    # Generate a deterministic invoice number based on distributor and month
    year_month = Date.current.strftime('%Y%m')
    base_number = "INV-AMB-#{year_month}-#{distributor_id.to_s.rjust(5, '0')}"

    # Check if this exact number exists
    counter = 1
    invoice_number = base_number

    while Invoice.exists?(invoice_number: invoice_number)
      invoice_number = "#{base_number}-#{counter}"
      counter += 1
    end

    invoice_number
  end

  def generate_ambassador_invoice_number
    "INV-AMB-#{Date.current.strftime('%Y%m%d')}-#{rand(10000..99999)}"
  end

  def authorize_admin_access
    redirect_to root_path unless current_user&.user_type == 'admin'
  end
end
