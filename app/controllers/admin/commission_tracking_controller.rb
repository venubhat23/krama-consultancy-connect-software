require 'ostruct'

class Admin::CommissionTrackingController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin_access
  before_action :find_policy, only: [:show, :policy_breakdown, :transfer_to_affiliate,
                                      :transfer_to_ambassador, :transfer_to_investor,
                                      :transfer_company_expense, :mark_main_agent_commission_received,
                                      :settle_distribution_payouts]

  skip_authorization_check
  skip_load_and_authorize_resource

  def index
    @tab = params[:tab] || 'all'
    @filter_customer_id = params[:customer_id]
    @filter_date_from   = params[:date_from]
    @filter_date_to     = params[:date_to]
    @filter_month       = params[:month]
    @filter_year        = params[:year]

    if @filter_customer_id.present?
      customer = Customer.find_by(id: @filter_customer_id)
      @filter_customer_name = customer&.display_name
    end

    @customers_for_filter = Customer.order(:first_name, :last_name).limit(500).select(:id, :first_name, :middle_name, :last_name, :company_name, :customer_type)

    @page     = [params[:page].to_i, 1].max
    @per_page = [[params[:per_page].to_i, 5].max, 100].min
    @per_page = SystemSetting.default_pagination_per_page if params[:per_page].blank?
    @items_per_page = @per_page

    begin
      filtered_scope = base_filtered_payout_scope
      @all_count     = filtered_scope.count
      @paid_count    = filtered_scope.where(main_agent_commission_received: true).count
      @pending_count = filtered_scope.where(main_agent_commission_received: [false, nil]).count

      @policies_with_commission = fetch_policies_with_commission_filtered

      date_from = @filter_date_from.present? ? (Date.parse(@filter_date_from) rescue nil) : nil
      date_to   = @filter_date_to.present?   ? (Date.parse(@filter_date_to)   rescue nil) : nil

      @total_commission_generated = calculate_total_commission_generated(date_from, date_to)
      @total_transferred = calculate_total_transferred(date_from, date_to)
      @pending_transfers = calculate_pending_transfers
      @company_expenses = calculate_company_expenses(date_from, date_to)
    rescue => e
      Rails.logger.error "Commission tracking failed: #{e.message}"

      @all_count            = 0
      @paid_count           = 0
      @pending_count        = 0
      @total_policies_count = 0
      @paginated_payouts    = nil
      date_from = @filter_date_from.present? ? (Date.parse(@filter_date_from) rescue nil) : nil
      date_to   = @filter_date_to.present?   ? (Date.parse(@filter_date_to)   rescue nil) : nil
      @total_commission_generated = calculate_total_commission_generated(date_from, date_to)
      @total_transferred = calculate_total_transferred(date_from, date_to)
      @pending_transfers = calculate_pending_transfers
      @company_expenses = calculate_company_expenses(date_from, date_to)
      @policies_with_commission = create_sample_policies
    end
  end

  def show
    # Check if we have saved payout data
    policy_type = @policy.class.name.underscore.gsub('_insurance', '')
    saved_payout = Payout.find_by(policy_type: policy_type, policy_id: @policy.id)

    @commission_breakdown = if saved_payout
                             get_policy_breakdown_from_payout(saved_payout)
                           else
                             CommissionCalculatorService.get_policy_commission_summary(@policy)
                           end

    @transfer_history = fetch_transfer_history(@policy)
    @saved_payout = saved_payout
  end

  def policy_breakdown
    # Check if we have saved payout data
    policy_type = @policy.class.name.underscore.gsub('_insurance', '')
    saved_payout = Payout.find_by(policy_type: policy_type, policy_id: @policy.id)

    @commission_breakdown = if saved_payout
                             get_policy_breakdown_from_payout(saved_payout)
                           else
                             CommissionCalculatorService.get_policy_commission_summary(@policy)
                           end

    respond_to do |format|
      format.json { render json: @commission_breakdown }
      format.html
    end
  end

  def transfer_to_affiliate
    result = process_manual_transfer(
      policy: @policy,
      transfer_type: 'affiliate',
      amount: params[:amount],
      transaction_id: params[:transaction_id],
      notes: params[:notes]
    )

    respond_with_transfer_result(result)
  end

  def transfer_to_ambassador
    result = process_manual_transfer(
      policy: @policy,
      transfer_type: 'ambassador',
      amount: params[:amount],
      transaction_id: params[:transaction_id],
      notes: params[:notes]
    )

    respond_with_transfer_result(result)
  end

  def transfer_to_investor
    result = process_manual_transfer(
      policy: @policy,
      transfer_type: 'investor',
      amount: params[:amount],
      transaction_id: params[:transaction_id],
      notes: params[:notes]
    )

    respond_with_transfer_result(result)
  end

  def transfer_company_expense
    result = process_manual_transfer(
      policy: @policy,
      transfer_type: 'company_expense',
      amount: params[:amount],
      transaction_id: params[:transaction_id],
      notes: params[:notes]
    )

    respond_with_transfer_result(result)
  end

  def mark_main_agent_commission_received
    transaction_id = params[:transaction_id]
    paid_date = params[:paid_date]
    notes = params[:notes]

    if transaction_id.blank?
      return render json: { success: false, message: 'Transaction ID is required' }, status: :unprocessable_entity
    end

    begin
      policy_type = @policy.class.name.underscore.gsub('_insurance', '')
      paid_date_parsed = paid_date.present? ? Date.parse(paid_date) : Date.current

      # Update the policy record
      @policy.update!(
        main_agent_commission_received: true,
        main_agent_commission_transaction_id: transaction_id,
        main_agent_commission_paid_date: paid_date_parsed,
        main_agent_commission_notes: notes
      )

      # Update the corresponding Payout record
      payout_record = Payout.find_by(
        policy_type: policy_type,
        policy_id: @policy.id
      )

      if payout_record
        payout_record.update!(
          main_agent_commission_received: true,
          main_agent_commission_transaction_id: transaction_id,
          main_agent_commission_paid_date: paid_date_parsed,
          main_agent_commission_notes: notes,
          notes: "#{payout_record.notes || ''}\nMain agent commission paid - Transaction: #{transaction_id} on #{paid_date_parsed.strftime('%Y-%m-%d')}".strip
        )
        Rails.logger.info "Updated Payout #{payout_record.id} with main agent commission details"
      else
        Rails.logger.warn "No Payout found for policy #{@policy.id} (#{policy_type})"
      end

      # Also update the corresponding CommissionPayout record for main agent
      commission_payout = CommissionPayout.find_by(
        policy_type: policy_type,
        policy_id: @policy.id,
        payout_to: 'main_agent'
      )

      if commission_payout
        commission_payout.update!(
          status: 'paid',
          payout_date: paid_date_parsed,
          transaction_id: transaction_id,
          notes: notes,
          processed_by: current_user&.email || 'admin',
          processed_at: Time.current
        )
        Rails.logger.info "Updated CommissionPayout #{commission_payout.id} status to paid"
      else
        Rails.logger.warn "No CommissionPayout found for policy #{@policy.id} (#{policy_type}) main_agent"
      end

      render json: {
        success: true,
        message: 'Main agent commission marked as received successfully',
        data: {
          policy_id: @policy.id,
          policy_number: @policy.policy_number,
          transaction_id: transaction_id,
          paid_date: @policy.main_agent_commission_paid_date&.strftime('%d %b %Y'),
          received_status: true,
          commission_payout_updated: commission_payout.present?
        }
      }
    rescue StandardError => e
      Rails.logger.error "Failed to mark main agent commission as received for policy #{@policy.id}: #{e.message}"
      render json: {
        success: false,
        message: 'Failed to update commission status. Please try again.'
      }, status: :internal_server_error
    end
  end

  # Triggered from the Affiliate "Pay" button: settles Affiliate, Ambassador, Investor
  # and Company payouts for the policy in one atomic step, since they're always
  # distributed together once the Main Agent commission has been paid.
  def settle_distribution_payouts
    policy_type = @policy.class.name.underscore.gsub('_insurance', '')
    main_payout = CommissionPayout.find_by(policy_type: policy_type, policy_id: @policy.id, payout_to: 'main_agent')

    unless main_payout&.status == 'paid'
      return render json: { success: false, message: 'Main Agent commission must be paid first' }, status: :unprocessable_entity
    end

    transaction_id = params[:transaction_id].presence || "BULK-#{policy_type.upcase}-#{@policy.id}-#{Time.current.to_i}"
    paid_date = params[:paid_date].present? ? (Date.parse(params[:paid_date]) rescue Date.current) : Date.current
    notes = params[:notes].presence || 'Settled together with Affiliate payout'

    amounts = {
      'affiliate'       => (@policy.try(:sub_agent_after_tds_value) || 0).to_f,
      'ambassador'      => (@policy.try(:ambassador_after_tds_value) || @policy.try(:ambassador_commission_amount) || 0).to_f,
      'investor'        => (@policy.try(:investor_after_tds_value) || @policy.try(:investor_commission_amount) || 0).to_f,
      'company_expense' => (@policy.try(:company_expenses_amount) || 0).to_f
    }

    settled = {}

    ActiveRecord::Base.transaction do
      amounts.each do |transfer_type, amount|
        payout = CommissionPayout.find_or_initialize_by(policy_type: policy_type, policy_id: @policy.id, payout_to: transfer_type)
        payout.payout_amount = amount if payout.new_record?
        payout.assign_attributes(
          status: 'paid',
          payout_date: paid_date,
          transaction_id: transaction_id,
          notes: notes,
          processed_by: current_user&.email || 'admin',
          processed_at: Time.current
        )
        payout.save!
        settled[transfer_type] = amount

        begin
          generate_invoice_for_transfer(@policy, payout)
        rescue => e
          Rails.logger.error "Invoice generation failed during distribution settle (#{transfer_type}): #{e.message}"
        end
      end
    end

    render json: {
      success: true,
      message: 'Affiliate, Ambassador, Investor and Company payouts settled successfully',
      data: { transaction_id: transaction_id, paid_date: paid_date.strftime('%d %b %Y'), amounts: settled }
    }
  rescue StandardError => e
    Rails.logger.error "Settling distribution payouts failed for policy #{@policy&.id}: #{e.message}"
    render json: { success: false, message: 'Failed to settle payouts. Please try again.' }, status: :internal_server_error
  end

  def manual_transfer
    policy = find_policy_by_params

    unless policy
      return render json: { success: false, message: 'Policy not found' }, status: :not_found
    end

    result = process_manual_transfer(
      policy: policy,
      transfer_type: params[:transfer_type],
      amount: params[:amount],
      transaction_id: params[:transaction_id],
      notes: params[:notes]
    )

    render json: result
  end

  def policy_search
    search_term = params[:search]
    policies = []

    if search_term.present?
      policies = search_policies_across_types(search_term)
    end

    respond_to do |format|
      format.json { render json: policies }
      format.html { @policies = policies }
    end
  end

  def search_customers
    query = params[:q].to_s.strip
    customers = if query.present?
      Customer.where(
        "first_name ILIKE :q OR last_name ILIKE :q OR CONCAT(first_name, ' ', last_name) ILIKE :q",
        q: "%#{query}%"
      ).order(:first_name).limit(30)
    else
      Customer.order(:first_name).limit(30)
    end.select(:id, :first_name, :last_name)

    render json: {
      results: customers.map { |c| { id: c.id, text: "#{c.first_name} #{c.last_name}".strip } }
    }
  end

  def summary
    @summary_data = {
      monthly_breakdown: monthly_commission_breakdown,
      policy_type_breakdown: policy_type_commission_breakdown,
      transfer_status_breakdown: transfer_status_breakdown
    }

    respond_to do |format|
      format.json { render json: @summary_data }
      format.html
    end
  end

  private

  def create_sample_policies
    # Create sample data for emergency fallback
    sample_policies = []

    (1..10).each do |i|
      premium = 50000 + (i * 1000)
      # Use realistic commission structure
      main_commission = premium * 0.10 # 10% main commission
      affiliate_commission = premium * 0.02 # 2% affiliate
      ambassador_commission = premium * 0.02 # 2% ambassador
      investor_commission = premium * 0.01 # 1% investor
      company_expense = premium * 0.03 # 3% company expense

      sample_policies << {
        policy: OpenStruct.new(
          id: i,
          policy_number: "SAMPLE-#{i}",
          total_premium: premium,
          insurance_company_name: 'Sample Insurance Co.',
          lead_id: "LEAD-SAMPLE-#{i}",
          main_agent_commission_received: false,
          main_agent_commission_paid_date: nil,
          created_at: Time.current - i.days,
          customer: OpenStruct.new(display_name: "Sample Customer #{i}"),
          try: ->(method) { nil }
        ),
        type: i.odd? ? 'health' : 'life',
        commission_data: {
          summary: { total_commission_generated: main_commission },
          main_agent: { total_commission: main_commission, percentage: 10.0 },
          payouts: {
            affiliate: affiliate_commission,
            ambassador: ambassador_commission,
            investor: investor_commission,
            company_expense: company_expense
          },
          percentages: {
            main_agent: 10.0,
            affiliate: 2.0,
            ambassador: 2.0,
            investor: 1.0,
            company_expense: 3.0
          }
        },
        transfer_status: {
          total_payouts: 4,
          paid_payouts: i > 5 ? 2 : 0,
          pending_payouts: i > 5 ? 2 : 4,
          total_amount: affiliate_commission + ambassador_commission + investor_commission + company_expense,
          paid_amount: i > 5 ? (affiliate_commission + ambassador_commission) : 0
        },
        saved_payout: nil,
        created_at: Time.current - i.days
      }
    end

    sample_policies
  end

  public

  def dashboard
    @commission_summary = { total_generated: 0, total_transferred: 0, pending_transfers: 0, company_expenses: 0 }

    begin
      @commission_summary = {
        total_generated: calculate_total_commission_generated || 0,
        total_transferred: calculate_total_transferred || 0,
        pending_transfers: calculate_pending_transfers || 0,
        company_expenses: calculate_company_expenses || 0
      }

      @recent_policies = fetch_recent_policies_with_commission || []
      @transfer_summary = fetch_transfer_summary || {}

      # Calculate real-time statistics
      @active_affiliates = SubAgent.active.count
      @lead_conversion_rate = calculate_lead_conversion_rate
      @avg_policy_value = calculate_average_policy_value
      @commissions_due = calculate_commissions_due

      # Get premium revenue trend data (last 6 months)
      @premium_trend_data = calculate_premium_trend

    rescue => e
      Rails.logger.error "Dashboard data fetch failed: #{e.message}"
      # Fallback data
      @commission_summary = {
        total_generated: 0,
        total_transferred: 0,
        pending_transfers: 0,
        company_expenses: 0
      }
      @recent_policies = []
      @transfer_summary = {}
      @active_affiliates = 0
      @lead_conversion_rate = 0.0
      @avg_policy_value = 0
      @commissions_due = 0
      @premium_trend_data = []
    end

    # Render the new attractive financial dashboard
    # Now using the default dashboard.html.erb template
  end

  def commission_details_modal
    # Endpoint for fetching commission details for modal
    @pending_commissions = CommissionPayout.includes(:policy)
                                           .where(status: 'pending')
                                           .order(created_at: :desc)

    respond_to do |format|
      format.json do
        render json: {
          success: true,
          data: @pending_commissions.map do |payout|
            policy = get_policy_for_payout(payout)
            {
              id: payout.id,
              lead_id: policy&.lead_id || 'N/A',
              policy_number: policy&.policy_number || 'N/A',
              customer_name: policy&.customer&.display_name || 'N/A',
              policy_type: payout.policy_type,
              payout_to: payout.payout_to,
              amount: payout.payout_amount,
              created_at: payout.created_at.strftime("%d %b %Y")
            }
          end,
          total_amount: @pending_commissions.sum(:payout_amount)
        }
      end
    end
  end

  def modern_dashboard
    # Initialize with defaults first
    @commission_summary = {
      total_generated: 0,
      total_transferred: 0,
      pending_transfers: 0,
      company_expenses: 0
    }
    @recent_policies = []
    @transfer_summary = {}

    begin
      # Calculate commission summary
      @commission_summary = {
        total_generated: calculate_total_commission_generated || 0,
        total_transferred: calculate_total_transferred || 0,
        pending_transfers: calculate_pending_transfers || 0,
        company_expenses: calculate_company_expenses || 0
      }

      # Fetch related data
      @recent_policies = fetch_recent_policies_with_commission || []
      @transfer_summary = fetch_transfer_summary || {}

      Rails.logger.info "Modern dashboard loaded successfully. Commission summary: #{@commission_summary}"
    rescue => e
      Rails.logger.error "Modern dashboard data fetch failed: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(5).join('\n')}"

      # Keep the default values already set above
      flash[:warning] = "Some dashboard data couldn't be loaded. Showing default values."
    end

    render 'admin/commission_tracking/modern_dashboard'
  end

  private

  def find_policy
    policy_type = params[:policy_type] || params[:type]
    policy_id = params[:id] || params[:policy_id]

    @policy = case policy_type&.downcase
              when 'health'
                HealthInsurance.find(policy_id)
              when 'life'
                LifeInsurance.find(policy_id)
              when 'motor'
                MotorInsurance.find(policy_id)
              when 'other'
                OtherInsurance.find(policy_id)
              else
                # Try to find in all tables if policy_type is not specified
                find_policy_across_types(policy_id)
              end
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_commission_tracking_index_path, alert: 'Policy not found'
  end

  def find_policy_by_params
    policy_type = params[:policy_type]
    policy_id = params[:policy_id]

    case policy_type&.downcase
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

  def find_policy_across_types(policy_id)
    [HealthInsurance, LifeInsurance, MotorInsurance, OtherInsurance].each do |model|
      policy = model.find_by(id: policy_id)
      return policy if policy
    end
    nil
  end

  def search_policies_across_types(search_term)
    policies = []

    # Search Health Insurance
    HealthInsurance.joins(:customer)
                   .where("health_insurances.policy_number ILIKE ? OR customers.first_name ILIKE ? OR customers.last_name ILIKE ?",
                          "%#{search_term}%", "%#{search_term}%", "%#{search_term}%")
                   .limit(10).each do |policy|
      policies << format_policy_for_search(policy, 'health')
    end

    # Search Life Insurance
    LifeInsurance.joins(:customer)
                 .where("life_insurances.policy_number ILIKE ? OR customers.first_name ILIKE ? OR customers.last_name ILIKE ?",
                        "%#{search_term}%", "%#{search_term}%", "%#{search_term}%")
                 .limit(10).each do |policy|
      policies << format_policy_for_search(policy, 'life')
    end

    # Search Motor Insurance
    MotorInsurance.joins(:customer)
                  .where("motor_insurances.policy_number ILIKE ? OR customers.first_name ILIKE ? OR customers.last_name ILIKE ?",
                         "%#{search_term}%", "%#{search_term}%", "%#{search_term}%")
                  .limit(10).each do |policy|
      policies << format_policy_for_search(policy, 'motor')
    end

    policies
  end

  def format_policy_for_search(policy, type)
    {
      id: policy.id,
      type: type,
      policy_number: policy.policy_number,
      customer_name: policy.customer.display_name,
      premium: policy.total_premium,
      commission_status: get_commission_status(policy, type)
    }
  end

  def get_commission_status(policy, type)
    breakdown = CommissionCalculatorService.calculate_commission_breakdown(policy)
    return 'no_commission' if breakdown.empty?

    existing_payouts = CommissionPayout.where(
      policy_type: type,
      policy_id: policy.id
    )

    if existing_payouts.any?
      paid_count = existing_payouts.where(status: 'paid').count
      total_count = existing_payouts.count

      if paid_count == total_count
        'fully_transferred'
      elsif paid_count > 0
        'partially_transferred'
      else
        'pending_transfer'
      end
    else
      'no_transfers_created'
    end
  end

  def base_filtered_payout_scope
    scope = Payout.all

    if @filter_customer_id.present?
      customer = Customer.find_by(id: @filter_customer_id)
      if customer
        health_ids = HealthInsurance.where(customer_id: customer.id).pluck(:id)
        life_ids   = LifeInsurance.where(customer_id: customer.id).pluck(:id)
        motor_ids  = MotorInsurance.where(customer_id: customer.id).pluck(:id)
        other_ids  = OtherInsurance.where(customer_id: customer.id).pluck(:id)

        scope = scope.where(
          "(policy_type = 'health' AND policy_id IN (:h)) OR " \
          "(policy_type = 'life'   AND policy_id IN (:l)) OR " \
          "(policy_type = 'motor'  AND policy_id IN (:m)) OR " \
          "(policy_type = 'other'  AND policy_id IN (:o))",
          h: health_ids.presence || [0],
          l: life_ids.presence   || [0],
          m: motor_ids.presence  || [0],
          o: other_ids.presence  || [0]
        )
      end
    end

    if @filter_date_from.present?
      scope = scope.where('created_at >= ?', Date.parse(@filter_date_from).beginning_of_day)
    end
    if @filter_date_to.present?
      scope = scope.where('created_at <= ?', Date.parse(@filter_date_to).end_of_day)
    end

    if @filter_month.present? && @filter_year.present?
      scope = scope.where(
        'EXTRACT(MONTH FROM created_at) = ? AND EXTRACT(YEAR FROM created_at) = ?',
        @filter_month.to_i, @filter_year.to_i
      )
    elsif @filter_year.present?
      scope = scope.where('EXTRACT(YEAR FROM created_at) = ?', @filter_year.to_i)
    elsif @filter_month.present?
      scope = scope.where('EXTRACT(MONTH FROM created_at) = ?', @filter_month.to_i)
    end

    scope
  end

  def fetch_policies_with_commission_filtered
    payout_scope = case @tab
                   when 'paid'    then base_filtered_payout_scope.where(main_agent_commission_received: true)
                   when 'pending' then base_filtered_payout_scope.where(main_agent_commission_received: [false, nil])
                   else                base_filtered_payout_scope
                   end

    @paginated_payouts    = payout_scope.order(created_at: :desc).page(@page).per(@per_page)
    @total_policies_count = @paginated_payouts.total_count

    build_policies_from_payouts(@paginated_payouts)
  end

  def fetch_policies_with_commission_optimized(page = 1, per_page = 10)
    page = page.to_i
    page = 1 if page < 1

    payout_scope = case @tab
                   when 'paid'    then Payout.where(main_agent_commission_received: true)
                   when 'pending' then Payout.where(main_agent_commission_received: [false, nil])
                   else                Payout.all
                   end

    offset = (page - 1) * per_page
    payouts = payout_scope.order(created_at: :desc).limit(per_page).offset(offset)
    @total_policies_count = payout_scope.count
    @total_pages = (@total_policies_count.to_f / per_page).ceil
    @has_next_page = page < @total_pages
    @has_prev_page = page > 1

    build_policies_from_payouts(payouts)
  end

  def fetch_policies_with_commission
    fetch_policies_with_commission_optimized(1, 50)
  end

  def build_policies_from_payouts(payouts)
    all_policies = []

    payouts_array = payouts.to_a

    life_policy_ids   = payouts_array.select { |p| p.policy_type == 'life' }.map(&:policy_id)
    health_policy_ids = payouts_array.select { |p| p.policy_type == 'health' }.map(&:policy_id)
    motor_policy_ids  = payouts_array.select { |p| p.policy_type == 'motor' }.map(&:policy_id)
    other_policy_ids  = payouts_array.select { |p| p.policy_type == 'other' }.map(&:policy_id)

    life_policies   = life_policy_ids.any?   ? LifeInsurance.includes(:customer).where(id: life_policy_ids).index_by(&:id)     : {}
    health_policies = health_policy_ids.any? ? HealthInsurance.includes(:customer).where(id: health_policy_ids).index_by(&:id) : {}
    motor_policies  = motor_policy_ids.any?  ? MotorInsurance.includes(:customer).where(id: motor_policy_ids).index_by(&:id)   : {}
    other_policies  = other_policy_ids.any?  ? OtherInsurance.includes(:customer).where(id: other_policy_ids).index_by(&:id)   : {}

    payouts_array.each do |payout|
      begin
        policy = case payout.policy_type
                 when 'health' then health_policies[payout.policy_id]
                 when 'life'   then life_policies[payout.policy_id]
                 when 'motor'  then motor_policies[payout.policy_id]
                 when 'other'  then other_policies[payout.policy_id]
                 end

        next unless policy && policy.customer

        all_policies << {
          policy: OpenStruct.new(
            id: policy.id,
            policy_number: policy.policy_number || "#{payout.policy_type.upcase}-#{policy.id}",
            total_premium: policy.total_premium || 0,
            insurance_company_name: policy.insurance_company_name || 'Unknown',
            lead_id: policy.lead_id,
            main_agent_commission_received: false,
            main_agent_commission_paid_date: nil,
            created_at: policy.created_at,
            customer: OpenStruct.new(display_name: policy.customer.display_name || "#{policy.customer.first_name} #{policy.customer.last_name}".strip),
            try: ->(method) { policy.send(method) rescue nil }
          ),
          type: payout.policy_type,
          commission_data: get_commission_data_from_payout(payout),
          transfer_status: get_transfer_status_from_payout(payout),
          saved_payout: payout,
          created_at: payout.created_at
        }
      rescue => e
        Rails.logger.warn "Error processing payout #{payout.id}: #{e.message}"
        next
      end
    end

    all_policies
  end

  PAYABLE_PAYOUT_TYPES = %w[main_agent affiliate ambassador].freeze

  def get_transfer_status_optimized(policy, type, all_payouts)
    policy_key = "#{type}_#{policy.id}"
    existing_payouts = (all_payouts[policy_key] || []).select { |p| PAYABLE_PAYOUT_TYPES.include?(p.payout_to) }

    paid_payouts    = existing_payouts.select { |p| p.status == 'paid' }
    pending_payouts = existing_payouts.select { |p| p.status == 'pending' }

    {
      total_payouts: existing_payouts.count,
      paid_payouts: paid_payouts.count,
      pending_payouts: pending_payouts.count,
      total_amount: existing_payouts.sum(&:payout_amount),
      paid_amount: paid_payouts.sum(&:payout_amount)
    }
  end

  def get_transfer_status(policy, type)
    existing_payouts = CommissionPayout.where(
      policy_type: type,
      policy_id: policy.id,
      payout_to: PAYABLE_PAYOUT_TYPES
    )

    {
      total_payouts: existing_payouts.count,
      paid_payouts: existing_payouts.where(status: 'paid').count,
      pending_payouts: existing_payouts.where(status: 'pending').count,
      total_amount: existing_payouts.sum(:payout_amount),
      paid_amount: existing_payouts.where(status: 'paid').sum(:payout_amount)
    }
  end

  def calculate_total_commission_generated(date_from = nil, date_to = nil)
    scope = Payout.all
    scope = scope.where('created_at >= ?', date_from.beginning_of_day) if date_from
    scope = scope.where('created_at <= ?', date_to.end_of_day)         if date_to
    scope.sum(:main_agent_commission_amount) || 0
  end

  def calculate_total_transferred(date_from = nil, date_to = nil)
    scope = CommissionPayout.where(payout_to: 'main_agent').where.not(status: 'pending')
    scope = scope.where('created_at >= ?', date_from.beginning_of_day) if date_from
    scope = scope.where('created_at <= ?', date_to.end_of_day)         if date_to
    scope.sum(:payout_amount) || 0
  end

  def calculate_pending_transfers
    # Pending = currently owed, not historical — no date filter
    CommissionPayout.where(payout_to: 'main_agent', status: 'pending').sum(:payout_amount) || 0
  end

  def calculate_company_expenses(date_from = nil, date_to = nil)
    scope = CommissionPayout.where(payout_to: 'company_expense').where.not(status: 'pending')
    scope = scope.where('created_at >= ?', date_from.beginning_of_day) if date_from
    scope = scope.where('created_at <= ?', date_to.end_of_day)         if date_to
    scope.sum(:payout_amount) || 0
  end

  def fetch_recent_policies_with_commission
    policies = []

    [HealthInsurance, LifeInsurance, MotorInsurance, OtherInsurance].each do |model|
      begin
        model.includes(:customer).order(created_at: :desc).limit(5).each do |policy|
          begin
            commission_data = CommissionCalculatorService.calculate_commission_breakdown(policy)
            next if commission_data.nil? || commission_data.empty?

            policies << {
              policy: policy,
              type: model.name.underscore.gsub('_insurance', ''),
              commission_data: commission_data
            }
          rescue => e
            Rails.logger.warn "Failed to calculate commission for #{model.name} policy #{policy.id}: #{e.message}"
            # Skip this policy and continue
            next
          end
        end
      rescue => e
        Rails.logger.warn "Failed to fetch recent policies for #{model.name}: #{e.message}"
        # Skip this model and continue with the next
        next
      end
    end

    policies.sort_by { |p| p[:policy].created_at }.reverse.take(20)
  rescue => e
    Rails.logger.error "Failed to fetch recent policies with commission: #{e.message}"
    []
  end

  def fetch_transfer_summary
    {
      affiliate: CommissionPayout.where(payout_to: 'affiliate').group(:status).sum(:payout_amount),
      ambassador: CommissionPayout.where(payout_to: 'ambassador').group(:status).sum(:payout_amount),
      investor: CommissionPayout.where(payout_to: 'investor').group(:status).sum(:payout_amount),
      company_expense: CommissionPayout.where(payout_to: 'company_expense').group(:status).sum(:payout_amount)
    }
  rescue => e
    Rails.logger.error "Failed to fetch transfer summary: #{e.message}"
    {
      affiliate: {},
      ambassador: {},
      investor: {},
      company_expense: {}
    }
  end

  def fetch_transfer_history(policy)
    policy_type = policy.class.name.underscore.gsub('_insurance', '')

    CommissionPayout.where(
      policy_type: policy_type,
      policy_id: policy.id
    ).order(created_at: :desc)
  end

  def process_manual_transfer(policy:, transfer_type:, amount:, transaction_id:, notes:)
    return { success: false, message: 'Invalid amount' } if amount.to_f <= 0

    policy_type = policy.class.name.underscore.gsub('_insurance', '')

    # Find existing payout or create new one
    payout = CommissionPayout.find_or_initialize_by(
      policy_type: policy_type,
      policy_id: policy.id,
      payout_to: transfer_type
    )

    if payout.new_record?
      # Calculate the amount based on commission breakdown
      breakdown = CommissionCalculatorService.calculate_commission_breakdown(policy)
      expected_amount = breakdown.dig(:payouts, transfer_type.to_sym) || 0

      payout.payout_amount = expected_amount
      payout.status = 'pending'
      payout.processed_by = current_user.email
    end

    # Mark as paid with transfer details
    payout.assign_attributes(
      status: 'paid',
      payout_date: Date.current,
      transaction_id: transaction_id,
      notes: notes,
      processed_by: current_user.email,
      processed_at: Time.current
    )

    if payout.save
      begin
        generate_invoice_for_transfer(policy, payout)
      rescue => e
        Rails.logger.error "Invoice generation failed after commission transfer: #{e.message}"
      end
      { success: true, message: "Transfer completed successfully", payout: payout }
    else
      { success: false, message: payout.errors.full_messages.join(', ') }
    end
  rescue StandardError => e
    Rails.logger.error "Manual transfer failed: #{e.message}"
    { success: false, message: 'Transfer failed. Please try again.' }
  end

  def respond_with_transfer_result(result)
    respond_to do |format|
      format.json { render json: result }
      format.html do
        if result[:success]
          redirect_to admin_commission_tracking_path(@policy, policy_type: @policy.class.name.underscore.gsub('_insurance', '')),
                      notice: result[:message]
        else
          redirect_to admin_commission_tracking_path(@policy, policy_type: @policy.class.name.underscore.gsub('_insurance', '')),
                      alert: result[:message]
        end
      end
    end
  end

  def monthly_commission_breakdown
    # Implementation for monthly breakdown
    {}
  end

  def policy_type_commission_breakdown
    # Implementation for policy type breakdown
    {}
  end

  def transfer_status_breakdown
    # Implementation for transfer status breakdown
    {}
  end

  def get_commission_data_from_payout(saved_payout)
    # Convert saved payout data to the format expected by the view
    # Use net_premium from policy if available, otherwise use total_commission_amount
    net_premium_value = (saved_payout.policy&.net_premium || saved_payout.total_commission_amount || 0).to_f.round(2)
    policy_premium = (saved_payout.policy&.total_premium || net_premium_value || 0).to_f.round(2)

    # Use stored percentages from payout when available, otherwise calculate based on net premium
    # Percentages should be calculated on net_premium (the commissionable amount), not total_premium
    commission_base = net_premium_value > 0 ? net_premium_value : policy_premium

    main_agent_amount = (saved_payout.main_agent_commission_amount || 0).to_f.round(2)
    main_agent_percentage = saved_payout.main_agent_percentage || (commission_base > 0 ? (main_agent_amount / commission_base * 100).round(1) : 0)

    affiliate_amount = (saved_payout.affiliate_commission_amount || 0).to_f.round(2)
    affiliate_percentage = saved_payout.affiliate_percentage || (commission_base > 0 ? (affiliate_amount / commission_base * 100).round(1) : 0)

    ambassador_amount = (saved_payout.ambassador_commission_amount || 0).to_f.round(2)
    ambassador_percentage = saved_payout.ambassador_percentage || (commission_base > 0 ? (ambassador_amount / commission_base * 100).round(1) : 0)

    investor_amount = (saved_payout.investor_commission_amount || 0).to_f.round(2)
    investor_percentage = saved_payout.investor_percentage || (commission_base > 0 ? (investor_amount / commission_base * 100).round(1) : 0)

    company_expense_amount = (saved_payout.company_expense_amount || 0).to_f.round(2)
    company_expense_percentage = saved_payout.company_expense_percentage || (commission_base > 0 ? (company_expense_amount / commission_base * 100).round(1) : 0)

    {
      summary: {
        total_commission_generated: net_premium_value
      },
      main_agent: {
        total_commission: main_agent_amount,
        percentage: main_agent_percentage
      },
      payouts: {
        affiliate: affiliate_amount,
        ambassador: ambassador_amount,
        investor: investor_amount,
        company_expense: company_expense_amount
      },
      percentages: {
        main_agent: main_agent_percentage,
        affiliate: affiliate_percentage,
        ambassador: ambassador_percentage,
        investor: investor_percentage,
        company_expense: company_expense_percentage
      }
    }
  end

  def get_policy_breakdown_from_payout(saved_payout)
    # Convert saved payout data to the full breakdown format expected by the show view

    # Calculate deductions (amounts taken from main agent) - ensure proper rounding
    main_agent_total = (saved_payout.main_agent_commission_amount || 0).to_f.round(2)
    affiliate_amount = (saved_payout.affiliate_commission_amount || 0).to_f.round(2)
    ambassador_amount = (saved_payout.ambassador_commission_amount || 0).to_f.round(2)
    investor_amount = (saved_payout.investor_commission_amount || 0).to_f.round(2)
    company_expense_amount = (saved_payout.company_expense_amount || 0).to_f.round(2)

    final_profit = (main_agent_total - affiliate_amount - ambassador_amount - investor_amount - company_expense_amount).round(2)

    # Get commission payout statuses
    commission_payouts = saved_payout.commission_payouts.index_by(&:payout_to)

    {
      policy: {
        number: saved_payout.policy&.policy_number || 'N/A',
        type: saved_payout.policy_type,
        customer: saved_payout.policy&.customer&.display_name || 'N/A',
        premium: saved_payout.policy&.total_premium || 0
      },
      commission_breakdown: {
        premium_amount: saved_payout.policy&.total_premium || 0,
        main_agent: {
          total_commission: main_agent_total,
          deductions: {
            affiliate: affiliate_amount,
            ambassador: ambassador_amount,
            investor: investor_amount,
            company_expense: company_expense_amount
          },
          final_profit: final_profit
        },
        payouts: {
          affiliate: affiliate_amount,
          ambassador: ambassador_amount,
          investor: investor_amount,
          company_expense: company_expense_amount
        },
        summary: {
          total_distributed: affiliate_amount + ambassador_amount + investor_amount,
          company_expense: company_expense_amount
        }
      },
      payout_status: {
        affiliate: get_payout_status(commission_payouts['affiliate']),
        ambassador: get_payout_status(commission_payouts['ambassador']),
        investor: get_payout_status(commission_payouts['investor']),
        company_expense: get_payout_status(commission_payouts['company_expense'])
      }
    }
  end

  def get_payout_status(commission_payout)
    if commission_payout
      {
        status: commission_payout.status,
        amount: commission_payout.payout_amount,
        payout_date: commission_payout.payout_date&.strftime("%b %d, %Y"),
        transaction_id: commission_payout.transaction_id
      }
    else
      {
        status: 'pending',
        amount: 0,
        payout_date: nil,
        transaction_id: nil
      }
    end
  end

  def get_transfer_status_from_payout(payout)
    payable_types = %w[main_agent affiliate ambassador]
    commission_payouts = (payout.commission_payouts || []).select { |cp| payable_types.include?(cp.payout_to) }

    {
      total_payouts: commission_payouts.count,
      paid_payouts: commission_payouts.count { |cp| cp.status == 'paid' },
      pending_payouts: commission_payouts.count { |cp| cp.status == 'pending' },
      total_amount: commission_payouts.sum(&:payout_amount),
      paid_amount: commission_payouts.select { |cp| cp.status == 'paid' }.sum(&:payout_amount)
    }
  end

  def authorize_admin_access
    redirect_to root_path unless current_user&.user_type == 'admin'
  end

  def calculate_lead_conversion_rate
    total_leads = Lead.count
    converted_leads = Lead.where.not(converted_customer_id: nil).count
    return 0.0 if total_leads.zero?
    ((converted_leads.to_f / total_leads) * 100).round(1)
  rescue => e
    Rails.logger.error "Error calculating lead conversion rate: #{e.message}"
    0.0
  end

  def calculate_average_policy_value
    total_premium = 0
    policy_count = 0

    [HealthInsurance, LifeInsurance, MotorInsurance, OtherInsurance].each do |model|
      total_premium += model.sum(:total_premium)
      policy_count += model.count
    end

    return 0 if policy_count.zero?
    (total_premium / policy_count).round
  rescue => e
    Rails.logger.error "Error calculating average policy value: #{e.message}"
    0
  end

  def calculate_commissions_due
    CommissionPayout.where(status: 'pending').sum(:payout_amount).round(2)
  rescue => e
    Rails.logger.error "Error calculating commissions due: #{e.message}"
    0
  end

  def calculate_premium_trend
    # Get last 6 months of data
    months = []
    6.downto(1) do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month

      month_data = {
        month: month_start.strftime("%b"),
        year: month_start.year,
        premium: 0
      }

      # Calculate total premium for each insurance type for this month
      [HealthInsurance, LifeInsurance, MotorInsurance, OtherInsurance].each do |model|
        month_data[:premium] += model.where(created_at: month_start..month_end).sum(:total_premium)
      end

      months << month_data
    end

    months
  rescue => e
    Rails.logger.error "Error calculating premium trend: #{e.message}"
    []
  end

  def get_policy_for_payout(payout)
    case payout.policy_type
    when 'health'
      HealthInsurance.find_by(id: payout.policy_id)
    when 'life'
      LifeInsurance.find_by(id: payout.policy_id)
    when 'motor'
      MotorInsurance.find_by(id: payout.policy_id)
    when 'other'
      OtherInsurance.find_by(id: payout.policy_id)
    else
      nil
    end
  end

  def generate_invoice_for_transfer(policy, payout)
    case payout.payout_to
    when 'affiliate'
      sub_agent_id = policy.respond_to?(:sub_agent_id) ? policy.sub_agent_id : nil
      return unless sub_agent_id.present?
      generate_monthly_affiliate_invoice_ct(sub_agent_id, payout.payout_date)
    when 'ambassador'
      distributor_id = policy.respond_to?(:distributor_id) ? policy.distributor_id : nil
      return unless distributor_id.present?
      generate_monthly_ambassador_invoice_ct(distributor_id, payout.payout_date)
    end
  end

  def generate_monthly_affiliate_invoice_ct(sub_agent_id, reference_date = nil)
    sub_agent = SubAgent.find_by(id: sub_agent_id)
    return unless sub_agent

    invoice_month = reference_date || Date.current
    month_start = invoice_month.beginning_of_month
    month_end = invoice_month.end_of_month

    existing_invoice = Invoice.where(
      payout_type: 'affiliate',
      payout_id: sub_agent_id,
      invoice_date: month_start..month_end
    ).first

    paid_payouts = CommissionPayout.where(payout_to: 'affiliate', status: 'paid')
                                   .where('payout_date BETWEEN ? AND ? OR (payout_date IS NULL AND updated_at BETWEEN ? AND ?)',
                                          month_start, month_end, month_start.to_time, (month_end + 1.day).to_time)
                                   .select do |cp|
      p = get_policy_for_payout(cp)
      p&.respond_to?(:sub_agent_id) && p.sub_agent_id.to_i == sub_agent_id.to_i
    end

    return if paid_payouts.empty?

    total_commission = paid_payouts.sum(&:payout_amount).to_f
    return if total_commission <= 0

    policies_processed = paid_payouts.map { |cp| get_policy_for_payout(cp)&.policy_number }.compact.uniq

    if existing_invoice
      existing_invoice.update!(
        total_amount: total_commission,
        notes: "Monthly affiliate commission for #{paid_payouts.count} policies in #{invoice_month.strftime('%B %Y')}: #{policies_processed.join(', ')}"
      )
    else
      invoice_number = generate_ct_invoice_number('AFF', sub_agent_id, invoice_month)
      Invoice.create!(
        invoice_number: invoice_number,
        payout_type: 'affiliate',
        payout_id: sub_agent_id,
        total_amount: total_commission,
        status: 'paid',
        invoice_date: invoice_month,
        due_date: invoice_month,
        paid_at: Time.current,
        recipient_name: "#{sub_agent.first_name} #{sub_agent.last_name}",
        recipient_email: sub_agent.email,
        notes: "Monthly affiliate commission for #{paid_payouts.count} policies in #{invoice_month.strftime('%B %Y')}: #{policies_processed.join(', ')}"
      )
    end
    Rails.logger.info "Generated/updated affiliate invoice for sub_agent #{sub_agent_id} in #{invoice_month.strftime('%B %Y')}"
  end

  def generate_monthly_ambassador_invoice_ct(distributor_id, reference_date = nil)
    distributor = Distributor.find_by(id: distributor_id)
    return unless distributor

    invoice_month = reference_date || Date.current
    month_start = invoice_month.beginning_of_month
    month_end = invoice_month.end_of_month

    existing_invoice = Invoice.where(
      payout_type: 'ambassador',
      payout_id: distributor_id,
      invoice_date: month_start..month_end
    ).first

    ambassador_payouts = CommissionPayout.where(payout_to: 'ambassador', status: 'paid')
                                         .where('payout_date BETWEEN ? AND ? OR (payout_date IS NULL AND updated_at BETWEEN ? AND ?)',
                                                month_start, month_end, month_start.to_time, (month_end + 1.day).to_time)
                                         .select do |cp|
      p = get_policy_for_payout(cp)
      p&.respond_to?(:distributor_id) && p.distributor_id.to_i == distributor_id.to_i
    end

    return if ambassador_payouts.empty?

    total_amount = ambassador_payouts.sum(&:payout_amount).to_f
    return if total_amount <= 0

    if existing_invoice
      existing_invoice.update!(
        total_amount: total_amount,
        notes: "Monthly ambassador commission for #{ambassador_payouts.count} payouts in #{invoice_month.strftime('%B %Y')}"
      )
    else
      invoice_number = generate_ct_invoice_number('AMB', distributor_id, invoice_month)
      Invoice.create!(
        invoice_number: invoice_number,
        payout_type: 'ambassador',
        payout_id: distributor_id,
        total_amount: total_amount,
        status: 'paid',
        invoice_date: invoice_month,
        due_date: invoice_month,
        paid_at: Time.current,
        recipient_name: distributor.display_name,
        recipient_email: distributor.email || 'no-email@example.com',
        notes: "Monthly ambassador commission for #{ambassador_payouts.count} payouts in #{invoice_month.strftime('%B %Y')}"
      )
    end
    Rails.logger.info "Generated/updated ambassador invoice for distributor #{distributor_id} in #{invoice_month.strftime('%B %Y')}"
  end

  def generate_ct_invoice_number(prefix, entity_id, month)
    year_month = month.strftime('%Y%m')
    base = "INV-#{prefix}-#{year_month}-#{entity_id.to_s.rjust(5, '0')}"
    counter = 1
    number = base
    while Invoice.exists?(invoice_number: number)
      number = "#{base}-#{counter}"
      counter += 1
    end
    number
  end
end