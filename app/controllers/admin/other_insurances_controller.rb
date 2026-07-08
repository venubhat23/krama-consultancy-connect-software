class Admin::OtherInsurancesController < Admin::ApplicationController
  include ConfigurablePagination

  before_action :set_other_insurance, only: [:show, :edit, :update, :destroy, :renew, :create_renewal, :regenerate_payout]
  before_action :load_form_data, only: [:new, :edit, :create, :update, :renew]
  skip_before_action :verify_authenticity_token, only: [:all_agency_codes, :all_brokers, :insurance_companies_for_type, :insurance_companies_by_agency]

  def index
    @current_tab = params[:tab] || 'drwise'

    # Base query
    @other_insurances = OtherInsurance.includes(:customer, :renewal_policy, :sub_agent)

    # Search functionality
    if params[:search].present?
      search_term = params[:search]
      @other_insurances = @other_insurances.joins(:customer).where(
        "other_insurances.policy_number ILIKE ? OR other_insurances.insurance_company_name ILIKE ? OR customers.first_name ILIKE ? OR customers.last_name ILIKE ? OR customers.company_name ILIKE ?",
        "%#{search_term}%", "%#{search_term}%", "%#{search_term}%", "%#{search_term}%", "%#{search_term}%"
      )
    end

    # Policy type filter
    if params[:policy_type].present?
      case params[:policy_type]
      when 'travel'
        @other_insurances = @other_insurances.where(insurance_type: 'Travel Insurance')
      when 'property'
        @other_insurances = @other_insurances.where(insurance_type: 'Property Insurance')
      when 'cyber'
        @other_insurances = @other_insurances.where(insurance_type: 'Cyber Insurance')
      when 'professional'
        @other_insurances = @other_insurances.where(insurance_type: 'Professional Indemnity')
      end
    end

    # Status filter (based on policy end date since there's no status column)
    if params[:status].present?
      case params[:status]
      when 'active'
        @other_insurances = @other_insurances.where('policy_end_date IS NULL OR policy_end_date >= ?', Date.current)
      when 'expired'
        @other_insurances = @other_insurances.where('policy_end_date < ?', Date.current)
      when 'pending'
        @other_insurances = @other_insurances.where('policy_start_date > ?', Date.current)
      end
    end

    # Advanced filters
    @other_insurances = @other_insurances.where(insurance_type: params[:insurance_type])      if params[:insurance_type].present?
    @other_insurances = @other_insurances.where(payment_mode: params[:payment_mode])           if params[:payment_mode].present?
    @other_insurances = @other_insurances.where(insurance_company_name: params[:company])      if params[:company].present?
    @other_insurances = @other_insurances.where(sub_agent_id: params[:sub_agent_id])           if params[:sub_agent_id].present?
    @other_insurances = @other_insurances.where("policy_start_date >= ?", params[:from_date])  if params[:from_date].present?
    @other_insurances = @other_insurances.where("policy_start_date <= ?", params[:to_date])    if params[:to_date].present?

    # Tab-based filtering using DrWise/Non-DrWise classification
    if @current_tab == 'drwise'
      @other_insurances = @other_insurances.where(
        is_admin_added: true,
        is_customer_added: false,
        is_agent_added: false
      )
    else
      @other_insurances = @other_insurances.where(
        '(is_customer_added = ? AND is_admin_added = ? AND is_agent_added = ?) OR (is_agent_added = ? AND is_customer_added = ? AND is_admin_added = ?)',
        true, false, false, true, false, false
      )
    end

    # Single query replaces 8 separate count/sum queries
    row = ActiveRecord::Base.connection.execute(<<~SQL).first
      SELECT
        COUNT(*) FILTER (WHERE is_admin_added AND NOT is_customer_added AND NOT is_agent_added)                                                              AS drwise_count,
        COUNT(*) FILTER (WHERE (is_customer_added AND NOT is_admin_added AND NOT is_agent_added) OR (is_agent_added AND NOT is_customer_added AND NOT is_admin_added)) AS non_drwise_count,
        COALESCE(SUM(total_premium) FILTER (WHERE is_admin_added AND NOT is_customer_added AND NOT is_agent_added), 0)                                       AS drwise_premium,
        COALESCE(SUM(sum_insured)   FILTER (WHERE is_admin_added AND NOT is_customer_added AND NOT is_agent_added), 0)                                       AS drwise_coverage,
        COALESCE(SUM(total_premium) FILTER (WHERE (is_customer_added AND NOT is_admin_added AND NOT is_agent_added) OR (is_agent_added AND NOT is_customer_added AND NOT is_admin_added)), 0) AS non_drwise_premium,
        COALESCE(SUM(sum_insured)   FILTER (WHERE (is_customer_added AND NOT is_admin_added AND NOT is_agent_added) OR (is_agent_added AND NOT is_customer_added AND NOT is_admin_added)), 0) AS non_drwise_coverage
      FROM other_insurances
    SQL
    @drwise_count        = row['drwise_count'].to_i
    @non_drwise_count    = row['non_drwise_count'].to_i
    @drwise_premium      = row['drwise_premium'].to_f
    @drwise_coverage     = row['drwise_coverage'].to_f
    @non_drwise_premium  = row['non_drwise_premium'].to_f
    @non_drwise_coverage = row['non_drwise_coverage'].to_f

    # Combine 4 separate pluck queries into 1 by fetching all needed columns at once
    dropdown_data = OtherInsurance.pluck(:insurance_company_name, :insurance_type, :payment_mode, :sub_agent_id)
    @filter_companies       = dropdown_data.map { |r| r[0] }.compact.uniq.reject(&:blank?).sort
    @filter_insurance_types = dropdown_data.map { |r| r[1] }.compact.uniq.reject(&:blank?).sort
    @filter_payment_modes   = dropdown_data.map { |r| r[2] }.compact.uniq.reject(&:blank?).sort
    sub_agent_ids           = dropdown_data.map { |r| r[3] }.compact.uniq
    @filter_sub_agents      = SubAgent.where(id: sub_agent_ids).order(:first_name, :last_name)

    @other_insurances = paginate_records(@other_insurances.order(policy_start_date: :desc))

    if @current_tab == 'drwise'
      @total_policies = @drwise_count
      @total_premium  = @drwise_premium
      @total_coverage = @drwise_coverage
    else
      @total_policies = @non_drwise_count
      @total_premium  = @non_drwise_premium
      @total_coverage = @non_drwise_coverage
    end
  end

  def show
  end

  def new
    @other_insurance = OtherInsurance.new
    @other_insurance.other_insurance_nominees.build

    # Pre-fill customer data if coming from customer page
    if params[:customer_id].present?
      @selected_customer = Customer.find(params[:customer_id])
      @other_insurance.customer_id = @selected_customer.id

      # Load family members for policy holder dropdown
      @customer_family_members = @selected_customer.family_members if @selected_customer

      # Auto-select affiliate based on customer
      @auto_select_affiliate = @selected_customer.sub_agent_id || 'self' if @selected_customer
    else
      @customer_family_members = []
    end
  end

  def edit
  end

  def create
    # Extract document files before creating the model
    main_policy_document = params[:other_insurance]&.delete(:main_policy_document)
    documents = params[:other_insurance]&.delete(:documents)

    # Extract uploaded_documents_attributes and their files
    uploaded_documents_data = extract_uploaded_documents_data

    @other_insurance = OtherInsurance.new(other_insurance_params)

    # Set admin tracking fields for policies created from admin panel
    @other_insurance.is_admin_added = true
    @other_insurance.is_customer_added = false
    @other_insurance.is_agent_added = false

    # Log the parameters for debugging
    Rails.logger.info "Creating OtherInsurance with params: #{other_insurance_params.inspect}"

    # Set calculated fields
    calculate_commission_fields if @other_insurance.net_premium.present?

    if @other_insurance.save
      Rails.logger.info "Successfully created OtherInsurance ##{@other_insurance.id}"

      # Handle R2 document uploads with extracted files
      handle_other_documents_r2_upload(@other_insurance, main_policy_document, documents)

      # Handle uploaded documents separately
      handle_uploaded_documents_r2_upload(@other_insurance, uploaded_documents_data)

      redirect_to admin_other_insurance_path(@other_insurance), notice: 'General insurance policy was successfully created.'
    else
      Rails.logger.error "Failed to create OtherInsurance: #{@other_insurance.errors.full_messages.join(', ')}"
      # Reload form data for re-rendering
      load_form_data
      @selected_customer = Customer.find(@other_insurance.customer_id) if @other_insurance.customer_id
      @customer_family_members = @selected_customer.family_members if @selected_customer
      render :new, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "Exception in OtherInsurance#create: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    flash[:error] = "An error occurred: #{e.message}"
    redirect_to new_admin_other_insurance_path
  end

  def update
    # Extract document files before updating the model
    main_policy_document = params[:other_insurance]&.delete(:main_policy_document)
    documents = params[:other_insurance]&.delete(:documents)

    # Extract uploaded_documents_attributes and their files
    uploaded_documents_data = extract_uploaded_documents_data

    if @other_insurance.update(other_insurance_params)
      # Handle R2 document uploads with extracted files
      handle_other_documents_r2_upload(@other_insurance, main_policy_document, documents)

      # Handle uploaded documents separately
      handle_uploaded_documents_r2_upload(@other_insurance, uploaded_documents_data)

      redirect_to admin_other_insurance_path(@other_insurance), notice: 'Other insurance policy was successfully updated.'
    else
      # Reload form data for re-rendering
      load_form_data
      @selected_customer = @other_insurance.customer
      @customer_family_members = @selected_customer.family_members if @selected_customer
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    policy_number = @other_insurance.policy_number
    customer_name = @other_insurance.customer&.display_name
    insurance_type = @other_insurance.insurance_type

    begin
      ActiveRecord::Base.transaction do
        # 1. Delete commission payouts for this other insurance
        CommissionPayout.where(policy_type: 'other', policy_id: @other_insurance.id).destroy_all

        # 2. Delete main payouts for this other insurance
        Payout.where(policy_type: 'other', policy_id: @other_insurance.id).destroy_all

        # 3. Delete lead record if it was created for this policy
        if @other_insurance.lead_id.present?
          lead = Lead.find_by(lead_id: @other_insurance.lead_id)
          if lead && lead.policy_created_id == @other_insurance.id
            lead.destroy
          end
        end

        # 4. Delete policy documents from R2 and database
        @other_insurance.policy_documents_records.each do |doc|
          # Delete from R2 if file key exists
          if doc.r2_file_key.present?
            R2Service.delete_file(doc.r2_file_key) rescue Rails.logger.warn("Failed to delete R2 file: #{doc.r2_file_key}")
          end
        end

        # 5. Delete other insurance specific documents from R2
        @other_insurance.other_insurance_documents.each do |doc|
          if doc.r2_file_key.present?
            R2Service.delete_file(doc.r2_file_key) rescue Rails.logger.warn("Failed to delete other insurance document from R2: #{doc.r2_file_key}")
          end
        end

        # 6. Delete main policy document from R2 if exists
        if @other_insurance.main_policy_document_key.present?
          R2Service.delete_file(@other_insurance.main_policy_document_key) rescue Rails.logger.warn("Failed to delete main policy from R2")
        end

        # 7. Delete uploaded documents and attached files
        @other_insurance.uploaded_documents.each do |doc|
          if doc.respond_to?(:file) && doc.file.attached?
            doc.file.purge rescue Rails.logger.warn("Failed to purge uploaded document")
          end
        end

        # 8. Delete Active Storage attachments
        @other_insurance.documents.purge rescue Rails.logger.warn("Failed to purge attached documents")
        @other_insurance.policy_documents.purge rescue Rails.logger.warn("Failed to purge policy documents")
        @other_insurance.additional_documents.purge rescue Rails.logger.warn("Failed to purge additional documents")

        # 9. Delete the other insurance record (this will cascade to dependent associations)
        @other_insurance.destroy!
      end

      redirect_to admin_other_insurances_path,
                  notice: "Other insurance policy #{policy_number} (#{insurance_type}) for #{customer_name} and all associated data were successfully deleted."

    rescue => e
      Rails.logger.error "Failed to delete other insurance #{@other_insurance.id}: #{e.message}"
      redirect_to admin_other_insurances_path,
                  alert: "Failed to delete other insurance policy. Error: #{e.message}"
    end
  end

  # API endpoint for getting all agency codes (for Direct selection)
  def all_agency_codes
    agency_codes = AgencyCode.where(insurance_type: ['Motor and Other Insurance', 'General Insurance', 'Other']).order(:agent_name, :code)
    render json: {
      agency_codes: agency_codes.map { |a| { id: a.id, name: "#{a.agent_name} - #{a.code}" } }
    }
  end

  # API endpoint for getting all brokers (for Broking selection)
  def all_brokers
    brokers = defined?(Broker) ? Broker.active.order(:name) : []
    render json: {
      brokers: brokers.map { |b| { id: b.id, name: b.name } }
    }
  end

  # API endpoint for getting agency codes or brokers based on broker type
  def agency_codes_for_broker_type
    broker_type = params[:broker_type]
    case broker_type
    when 'direct'
      # FLOW 1: Direct mode - Fetch agents for other insurance
      # API response format: { agent1: company_name_1, agent2: company_name_2 }
      agency_codes = AgencyCode.where('insurance_type ILIKE ?', '%other%')
                               .select(:id, :agent_name, :code, :company_name)
                               .order(:agent_name)
      # Transform to required format for dropdown
      agents_data = agency_codes.map { |ac|
        {
          id: ac.id,
          text: ac.agent_name,  # Show only agent name in dropdown
          agent_name: ac.agent_name,
          code: ac.code,
          company_name: ac.company_name
        }
      }
      render json: {
        success: true,
        data: agents_data
      }

    when 'broking'
      # FLOW 2: Broking mode - Fetch all brokers with their codes for other insurance
      # API response format: { broker1 with code, broker2 with code }
      brokers = Broker.active.includes(:broker_codes).order(:name)

      brokers_data = brokers.map { |broker|
        # Get the first active broker code for this broker
        first_code = broker.broker_codes.active.first

        {
          id: "broker_#{broker.id}",  # Use broker_X format for proper processing
          text: broker.name,  # Show broker name in dropdown
          broker_name: broker.name,
          code: first_code&.broker_code  # Include the broker code at root level
        }
      }

      render json: {
        success: true,
        data: brokers_data
      }

    else
      render json: { success: false, message: 'Invalid broker type. Use "direct" or "broking".' }
    end
  end

  # API endpoint for getting insurance companies by type
  def insurance_companies_for_type
    insurance_type = params[:insurance_type] || 'General Insurance'

    # Get companies for general/other insurance
    companies = InsuranceCompany.where(insurance_type: "motor_other").order('LOWER(name) ASC').pluck(:name)

    companies_data = companies.map { |name|
      {
        id: name,
        text: name
      }
    }

    render json: {
      success: true,
      data: companies_data
    }

  end

  # API endpoint for getting insurance companies by agency/broker selection
  # def insurance_companies_by_agency
  #   agency_id = params[:agency_id]
  #   broker_code = params[:broker_code]

  #   companies_data = []

  #   case params[:broker_type]
  #   when 'direct'
  #     # For direct mode: Get company from selected agency
  #     if agency_id.present?
  #       agency = AgencyCode.find_by(id: agency_id)
  #       companies_data = [{
  #         id: agency&.insurance_company,
  #         text: agency&.insurance_company || 'Unknown Company'
  #       }]
  #     end

  #   when 'broking'
  #     # For broking mode: Return all general insurance companies
  #     general_companies = ['New India Assurance', 'Oriental Insurance', 'National Insurance',
  #                         'United India Insurance', 'ICICI Lombard', 'Bajaj Allianz',
  #                         'Reliance General', 'Tata AIG', 'SBI General']

  #     companies_data = general_companies.map { |name|
  #       { id: name, text: name }
  #     }
  #   end

  #   render json: {
  #     success: true,
  #     data: companies_data
  #   }
  # end

  def regenerate_payout
    existing_payout = Payout.find_by(policy_type: 'other', policy_id: @other_insurance.id)
    if existing_payout
      redirect_to admin_other_insurance_path(@other_insurance), alert: 'Payout already exists for this policy.'
      return
    end

    unless @other_insurance.is_admin_added?
      redirect_to admin_other_insurance_path(@other_insurance), alert: 'Payout can only be generated for DrWise (admin-added) policies.'
      return
    end

    begin
      StructuredPayoutService.create_for_policy(@other_insurance, 'other')
      redirect_to admin_other_insurance_path(@other_insurance), notice: 'Payout generated successfully.'
    rescue => e
      Rails.logger.error "Failed to regenerate payout for other insurance #{@other_insurance.id}: #{e.message}"
      redirect_to admin_other_insurance_path(@other_insurance), alert: "Failed to generate payout: #{e.message}"
    end
  end

  def renew
    # Check if policy expires within 60 days
    if @other_insurance.policy_end_date.blank? || @other_insurance.policy_end_date > 60.days.from_now
      redirect_to admin_other_insurances_path, alert: "This policy is not eligible for renewal yet."
      return
    end

    # Create a new other insurance object with ALL data from the original policy
    @renewed_policy = @other_insurance.dup

    # Keep all the original policy data but update specific fields for renewal
    @renewed_policy.id = nil
    @renewed_policy.created_at = nil
    @renewed_policy.updated_at = nil

    # Set policy type to Renewal
    @renewed_policy.policy_type = 'Renewal'

    # Store original policy number for display
    @original_policy_number = @other_insurance.policy_number

    # Clear policy number (user needs to enter new one)
    @renewed_policy.policy_number = nil

    # Set booking date to current date
    @renewed_policy.policy_booking_date = Date.current

    # Calculate new policy dates based on payment mode
    if @other_insurance.policy_end_date.present?
      # Start date is day after current policy ends
      @renewed_policy.policy_start_date = @other_insurance.policy_end_date + 1.day

      # Calculate end date based on payment mode
      case @other_insurance.payment_mode
      when 'Yearly', 'Annual'
        @renewed_policy.policy_end_date = @renewed_policy.policy_start_date + 1.year - 1.day
      when 'Half Yearly', 'Semi-Annual'
        @renewed_policy.policy_end_date = @renewed_policy.policy_start_date + 6.months - 1.day
      when 'Quarterly'
        @renewed_policy.policy_end_date = @renewed_policy.policy_start_date + 3.months - 1.day
      when 'Monthly'
        @renewed_policy.policy_end_date = @renewed_policy.policy_start_date + 1.month - 1.day
      else
        # Default to yearly if payment mode is not recognized
        @renewed_policy.policy_end_date = @renewed_policy.policy_start_date + 1.year - 1.day
      end
    end

    # Auto-fill installment autopay dates based on new policy dates
    if @renewed_policy.policy_start_date.present? && @renewed_policy.policy_end_date.present?
      @renewed_policy.installment_autopay_start_date = @renewed_policy.policy_start_date
      @renewed_policy.installment_autopay_end_date = @renewed_policy.policy_end_date
    end

    # Clear commission tracking fields (these will be recalculated)
    @renewed_policy.main_agent_commission_received = nil
    @renewed_policy.main_agent_commission_transaction_id = nil
    @renewed_policy.main_agent_commission_paid_date = nil
    @renewed_policy.main_agent_commission_notes = nil

    # Clear lead_id and original_policy_id for new policy
    @renewed_policy.lead_id = nil
    @renewed_policy.original_policy_id = @other_insurance.id

    # Clear renewal flag
    @renewed_policy.is_renewed = false

    # Load form data for the renewal form
    load_form_data

    # Set up family members for Policy Holder dropdown
    @customer_family_members = []
    if @other_insurance.customer.present?
      @customer_family_members = @other_insurance.customer.family_members.to_a
    end

    # Auto-set affiliate based on original policy or customer
    if @renewed_policy.sub_agent_id.present?
      @auto_select_affiliate = @renewed_policy.sub_agent_id
    elsif @renewed_policy.customer.present? && @renewed_policy.customer.sub_agent_id.present?
      @renewed_policy.sub_agent_id = @renewed_policy.customer.sub_agent_id
      @auto_select_affiliate = @renewed_policy.customer.sub_agent_id
    else
      @auto_select_affiliate = 'self'
    end

    # Assign to instance variable for form
    @other_insurance = @renewed_policy
  end

  def create_renewal
    # Check if policy expires within 60 days
    if @other_insurance.policy_end_date.blank? || @other_insurance.policy_end_date > 60.days.from_now
      redirect_to admin_other_insurances_path, alert: "This policy is not eligible for renewal yet."
      return
    end

    # Create new policy with renewal data
    @renewed_policy = OtherInsurance.new(other_insurance_params)
    @renewed_policy.policy_type = 'Renewal'
    @renewed_policy.original_policy_id = @other_insurance.id

    # Preserve company name from original policy if the select didn't submit one
    @renewed_policy.insurance_company_name ||= @other_insurance.insurance_company_name

    # Set admin added flags for renewal (same as original)
    @renewed_policy.is_admin_added = @other_insurance.is_admin_added
    @renewed_policy.is_customer_added = @other_insurance.is_customer_added
    @renewed_policy.is_agent_added = @other_insurance.is_agent_added

    # Calculate all commission fields if net_premium is present
    if @renewed_policy.net_premium.present?
      net_premium = @renewed_policy.net_premium

      # Calculate main agent commission
      if @renewed_policy.main_agent_commission_percentage.present?
        @renewed_policy.commission_amount = (net_premium * @renewed_policy.main_agent_commission_percentage) / 100
        if @renewed_policy.tds_percentage.present?
          @renewed_policy.tds_amount = (@renewed_policy.commission_amount * @renewed_policy.tds_percentage) / 100
          @renewed_policy.after_tds_value = @renewed_policy.commission_amount - @renewed_policy.tds_amount
        end
      end

      # Calculate sub-agent commission
      if @renewed_policy.sub_agent_commission_percentage.present?
        @renewed_policy.sub_agent_commission_amount = (net_premium * @renewed_policy.sub_agent_commission_percentage) / 100
        if @renewed_policy.sub_agent_tds_percentage.present?
          @renewed_policy.sub_agent_tds_amount = (@renewed_policy.sub_agent_commission_amount * @renewed_policy.sub_agent_tds_percentage) / 100
          @renewed_policy.sub_agent_after_tds_value = @renewed_policy.sub_agent_commission_amount - @renewed_policy.sub_agent_tds_amount
        end
      end

      # Calculate ambassador commission
      if @renewed_policy.ambassador_commission_percentage.present?
        @renewed_policy.ambassador_commission_amount = (net_premium * @renewed_policy.ambassador_commission_percentage) / 100
        if @renewed_policy.ambassador_tds_percentage.present?
          @renewed_policy.ambassador_tds_amount = (@renewed_policy.ambassador_commission_amount * @renewed_policy.ambassador_tds_percentage) / 100
          @renewed_policy.ambassador_after_tds_value = @renewed_policy.ambassador_commission_amount - @renewed_policy.ambassador_tds_amount
        end
      end

      # Calculate investor commission
      if @renewed_policy.investor_commission_percentage.present?
        @renewed_policy.investor_commission_amount = (net_premium * @renewed_policy.investor_commission_percentage) / 100
        if @renewed_policy.investor_tds_percentage.present?
          @renewed_policy.investor_tds_amount = (@renewed_policy.investor_commission_amount * @renewed_policy.investor_tds_percentage) / 100
          @renewed_policy.investor_after_tds_value = @renewed_policy.investor_commission_amount - @renewed_policy.investor_tds_amount
        end
      end
    end

    if @renewed_policy.save
      # Mark original policy as renewed
      @other_insurance.update_column(:is_renewed, true)

      redirect_to admin_other_insurance_path(@renewed_policy),
                  notice: 'Other insurance renewal policy was successfully created.'
    else
      # Reload form data for error display
      load_form_data
      @customer_family_members = @renewed_policy.customer&.family_members || []

      # Set up affiliate selection
      if @renewed_policy.customer.present?
        if @renewed_policy.customer.sub_agent_id.present?
          @auto_select_affiliate = @renewed_policy.customer.sub_agent_id
        else
          @auto_select_affiliate = 'self'
        end
      end

      # Assign to instance variable for form
      @other_insurance = @renewed_policy
      render :renew, status: :unprocessable_entity
    end
  end

  def insurance_companies_by_agency
    broker_code = params[:broker_code]
    agency_code_id = params[:agency_code_id]
    if broker_code.blank? || agency_code_id.blank?
      render json: {
        success: false,
        message: 'Broker code and agency code ID are required'
      }
      return
    end

    companies_data = []

    case broker_code
    when 'direct'
      # For direct mode: Get companies mapped to the selected agency for other insurance
      company_names = AgencyCode.where(
        id: agency_code_id
      ).where('insurance_type ILIKE ?', '%other%')
       .or(AgencyCode.where(id: agency_code_id).where('insurance_type ILIKE ?', '%general%'))
       .or(AgencyCode.where(id: agency_code_id).where('insurance_type ILIKE ?', '%Motor and Other Insurance%'))
       .pluck(:company_name).compact.uniq

      if company_names.any?
        # Find insurance companies with fuzzy matching for motor_other type
        all_insurance_companies = InsuranceCompany.where(insurance_type: 'motor_other')
        matching_companies = []

        company_names.each do |agency_company_name|
          # Try exact match first
          exact_match = all_insurance_companies.find_by(name: agency_company_name)
          if exact_match
            matching_companies << exact_match
          else
            # Try fuzzy matching - prioritize brand name matches first
            agency_words = agency_company_name.downcase.split.reject { |w| w.length < 3 }

            # First priority: Brand name matches (TATA, BAJAJ, HDFC, etc.)
            brand_matches = all_insurance_companies.select do |company|
              company_words = company.name.downcase.split.reject { |w| w.length < 3 }
              (agency_words.include?('bajaj') && company_words.include?('bajaj')) ||
              (agency_words.include?('tata') && company_words.include?('tata')) ||
              (agency_words.include?('hdfc') && company_words.include?('hdfc')) ||
              (agency_words.include?('icici') && company_words.include?('icici')) ||
              (agency_words.include?('reliance') && company_words.include?('reliance')) ||
              (agency_words.include?('sbi') && company_words.include?('sbi')) ||
              (agency_words.include?('kotak') && company_words.include?('kotak'))
            end

            if brand_matches.any?
              # If we found brand matches, use only those
              matching_companies.concat(brand_matches)
            else
              # Fall back to general word matching if no brand matches
              fuzzy_matches = all_insurance_companies.select do |company|
                company_words = company.name.downcase.split.reject { |w| w.length < 3 }
                common_words = agency_words & company_words
                common_words.length >= 2
              end
              matching_companies.concat(fuzzy_matches.first(3))  # Limit to 3 matches
            end
          end
        end

        companies_data = matching_companies.uniq.map do |company|
          {
            id: company.id,
            text: company.name  # Changed from 'name' to 'text' to match frontend expectations
          }
        end
      end

    when 'broking'
      # For broking mode: Show all motor_other insurance companies
      insurance_companies = InsuranceCompany.where(insurance_type: 'motor_other')

      companies_data = insurance_companies.map do |company|
        {
          id: company.id,
          text: company.name  # Changed from 'name' to 'text' to match frontend expectations
        }
      end

    else
      render json: {
        success: false,
        message: 'Invalid broker code. Use "direct" or "broking".'
      }
      return
    end

    render json: {
      success: true,
      data: companies_data
    }
  end

  # API endpoint for loading customer nominees
  def load_customer_nominees
    customer_id = params[:customer_id]

    if customer_id.present?
      begin
        customer = Customer.find(customer_id)
        nominee_options = []

        # Include customer's own registered nominee first
        if customer.nominee_name.present?
          age = if customer.nominee_date_of_birth.present?
            ((Date.today - customer.nominee_date_of_birth) / 365.25).floor
          else
            0
          end
          nominee_options << {
            nominee_name: customer.nominee_name,
            relationship: customer.nominee_relation&.downcase || 'other',
            age: age
          }
        end

        # Add family members (skip if already added as primary nominee)
        customer.family_members.each do |member|
          next unless member.name.present? && member.name.strip.length > 0 && !member.name.strip.match?(/^\d+$/)
          next if customer.nominee_name.present? && member.name.strip.downcase == customer.nominee_name.strip.downcase

          nominee_options << {
            nominee_name: member.name,
            relationship: member.relationship&.downcase || 'other',
            age: member.age || 0
          }
        end

        render json: {
          success: true,
          nominees: nominee_options,
          customer_name: customer.display_name
        }
      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          message: 'Customer not found',
          nominees: []
        }
      end
    else
      render json: {
        success: false,
        message: 'Customer ID is required',
        nominees: []
      }
    end
  end

  # GET /admin/insurance/other/download
  def download
    format_type = params[:format_type]
    scope = build_other_filtered_scope.order(created_at: :desc)

    case format_type
    when 'csv'
      send_data generate_other_csv(scope),
                filename: "other_insurance_#{Date.current}.csv", type: 'text/csv'
    when 'excel'
      send_data generate_other_excel(scope),
                filename: "other_insurance_#{Date.current}.xlsx",
                type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    else
      redirect_to admin_other_insurances_path, alert: 'Invalid download format.'
    end
  end

  private

  def build_other_filtered_scope
    scope = OtherInsurance.includes(:customer, :sub_agent)
    current_tab = params[:tab] || 'drwise'
    if current_tab == 'drwise'
      scope = scope.where(is_admin_added: true, is_customer_added: false, is_agent_added: false)
    else
      scope = scope.where(
        '(is_customer_added = ? AND is_admin_added = ? AND is_agent_added = ?) OR (is_agent_added = ? AND is_customer_added = ? AND is_admin_added = ?)',
        true, false, false, true, false, false
      )
    end
    if params[:search].present?
      search_term = params[:search]
      scope = scope.joins(:customer).where(
        "other_insurances.policy_number ILIKE ? OR other_insurances.insurance_company_name ILIKE ? OR customers.first_name ILIKE ? OR customers.last_name ILIKE ? OR customers.company_name ILIKE ?",
        "%#{search_term}%", "%#{search_term}%", "%#{search_term}%", "%#{search_term}%", "%#{search_term}%"
      )
    end
    if params[:status].present?
      case params[:status]
      when 'active'        then scope = scope.where('policy_end_date IS NULL OR policy_end_date >= ?', Date.current)
      when 'expired'       then scope = scope.where('policy_end_date < ?', Date.current)
      when 'expiring_soon' then scope = scope.where(policy_end_date: Date.current..30.days.from_now)
      end
    end
    scope = scope.where(insurance_type: params[:insurance_type])      if params[:insurance_type].present?
    scope = scope.where(payment_mode: params[:payment_mode])          if params[:payment_mode].present?
    scope = scope.where(insurance_company_name: params[:company])     if params[:company].present?
    scope = scope.where(sub_agent_id: params[:sub_agent_id])          if params[:sub_agent_id].present?
    scope = scope.where("policy_start_date >= ?", params[:from_date]) if params[:from_date].present?
    scope = scope.where("policy_start_date <= ?", params[:to_date])   if params[:to_date].present?
    scope
  end

  def generate_other_csv(records)
    require 'csv'
    CSV.generate(headers: true) do |csv|
      csv << %w[ID PolicyNumber InsuranceType PolicyType CustomerName CustomerEmail
                InsuranceCompany SumInsured TotalPremium NetPremium PaymentMode
                PolicyStartDate PolicyEndDate Status Source Affiliate BookingDate CreatedAt]
      records.find_each do |p|
        source = if p.is_admin_added? then 'Admin' elsif p.is_agent_added? then 'Agent' elsif p.is_customer_added? then 'Customer' else 'Unknown' end
        status = if p.policy_end_date && p.policy_end_date < Date.current then 'Expired'
                 elsif p.policy_end_date && p.policy_end_date <= 30.days.from_now then 'Expiring Soon'
                 else 'Active' end
        csv << [p.id, p.policy_number, p.insurance_type, p.policy_type,
                p.customer&.display_name, p.customer&.email, p.insurance_company_name,
                p.sum_insured, p.total_premium, p.net_premium, p.payment_mode,
                p.policy_start_date, p.policy_end_date, status, source,
                p.sub_agent&.display_name, p.policy_booking_date, p.created_at.strftime('%Y-%m-%d %H:%M:%S')]
      end
    end
  end

  def generate_other_excel(records)
    require 'caxlsx'
    package = Axlsx::Package.new
    wb = package.workbook
    hdr = wb.styles.add_style(bg_color: '4A148C', fg_color: 'FFFFFF', b: true, alignment: { horizontal: :center })
    row = wb.styles.add_style(alignment: { horizontal: :left })
    wb.add_worksheet(name: 'General Insurance') do |sheet|
      sheet.add_row %w[ID PolicyNumber InsuranceType PolicyType CustomerName CustomerEmail
                       InsuranceCompany SumInsured TotalPremium NetPremium PaymentMode
                       PolicyStartDate PolicyEndDate Status Source Affiliate BookingDate CreatedAt], style: hdr
      records.find_each do |p|
        source = if p.is_admin_added? then 'Admin' elsif p.is_agent_added? then 'Agent' elsif p.is_customer_added? then 'Customer' else 'Unknown' end
        status = if p.policy_end_date && p.policy_end_date < Date.current then 'Expired'
                 elsif p.policy_end_date && p.policy_end_date <= 30.days.from_now then 'Expiring Soon'
                 else 'Active' end
        sheet.add_row [p.id, p.policy_number, p.insurance_type, p.policy_type,
                       p.customer&.display_name, p.customer&.email, p.insurance_company_name,
                       p.sum_insured.to_f, p.total_premium.to_f, p.net_premium.to_f, p.payment_mode,
                       p.policy_start_date&.to_s, p.policy_end_date&.to_s, status, source,
                       p.sub_agent&.display_name, p.policy_booking_date&.to_s, p.created_at.strftime('%Y-%m-%d %H:%M:%S')], style: row
      end
    end
    package.to_stream.read
  end

  def set_other_insurance
    @other_insurance = OtherInsurance.includes(:customer, :sub_agent, :agency_code).find(params[:id])
  end

  def load_form_data
    @customers = Customer.active.order(:first_name, :last_name, :company_name)
    @sub_agents = SubAgent.active.order(:first_name, :last_name)
    @distributors = Distributor.active.order(:first_name, :last_name)
    @investors = Investor.active.order(:first_name, :last_name)
    @agency_codes = AgencyCode.where(insurance_type: ['Motor and Other Insurance', 'General Insurance', 'Other']).order(:agent_name)
    @brokers = Broker.active.order(:name) if defined?(Broker)
    @insurance_companies = ['New India Assurance', 'Oriental Insurance', 'National Insurance', 'United India Insurance',
                           'ICICI Lombard', 'Bajaj Allianz', 'Reliance General', 'Tata AIG', 'SBI General']

    # Ensure the current policy's company is always available (in case it's not in the default list)
    if @other_insurance&.insurance_company_name.present?
      unless @insurance_companies.include?(@other_insurance.insurance_company_name)
        @insurance_companies = (@insurance_companies + [@other_insurance.insurance_company_name]).sort
      end
    end

    # Load customer family members if customer is selected
    if @other_insurance&.customer_id.present?
      @selected_customer = Customer.find(@other_insurance.customer_id)
      @customer_family_members = @selected_customer.family_members
      @auto_select_affiliate = @selected_customer.sub_agent_id || 'self'
    else
      @customer_family_members = []
    end
  end

  def other_insurance_params
    params.require(:other_insurance).permit(
      :customer_id, :policy_holder, :sub_agent_id, :broker_code_type, :agency_code_id,
      :broker_id, :insurance_company_name, :policy_type, :insurance_type, :payment_mode,
      :policy_number, :policy_booking_date, :policy_start_date, :policy_end_date,
      :plan_name, :sum_insured, :net_premium, :gst_percentage, :total_premium,
      :policy_term, :claim_process, :status,
      :main_agent_commission_percentage, :commission_amount, :tds_percentage,
      :tds_amount, :after_tds_value, :main_agent_commission_received,
      :main_agent_commission_paid_date, :main_agent_commission_transaction_id,
      :main_agent_commission_notes,
      :sub_agent_commission_percentage, :sub_agent_commission_amount,
      :sub_agent_tds_percentage, :sub_agent_tds_amount, :sub_agent_after_tds_value,
      :investor_commission_percentage, :investor_commission_amount,
      :investor_tds_percentage, :investor_tds_amount, :investor_after_tds_value,
      :ambassador_commission_percentage, :ambassador_commission_amount,
      :ambassador_tds_percentage, :ambassador_tds_amount, :ambassador_after_tds_value,
      :company_expenses_percentage, :total_distribution_percentage,
      :profit_percentage, :profit_amount,
      :installment_autopay_start_date, :installment_autopay_end_date,
      policy_documents: [], additional_documents: [],
      uploaded_documents_attributes: [:id, :title, :description, :document_type, :file, :uploaded_by, :_destroy],
      other_insurance_nominees_attributes: [:id, :nominee_name, :relationship, :age, :share_percentage, :_destroy],
      other_insurance_documents_attributes: [:id, :document_type, :title, :description, :file, :_destroy]
    )
  end

  def calculate_commission_fields
    return unless @other_insurance.net_premium.present?

    net_premium = @other_insurance.net_premium

    # Calculate main agent commission
    if @other_insurance.main_agent_commission_percentage.present?
      @other_insurance.commission_amount = (net_premium * @other_insurance.main_agent_commission_percentage) / 100

      if @other_insurance.tds_percentage.present?
        @other_insurance.tds_amount = (@other_insurance.commission_amount * @other_insurance.tds_percentage) / 100
        @other_insurance.after_tds_value = @other_insurance.commission_amount - @other_insurance.tds_amount
      end
    end

    # Calculate sub-agent commission
    if @other_insurance.sub_agent_commission_percentage.present?
      @other_insurance.sub_agent_commission_amount = (net_premium * @other_insurance.sub_agent_commission_percentage) / 100

      if @other_insurance.sub_agent_tds_percentage.present?
        @other_insurance.sub_agent_tds_amount = (@other_insurance.sub_agent_commission_amount * @other_insurance.sub_agent_tds_percentage) / 100
        @other_insurance.sub_agent_after_tds_value = @other_insurance.sub_agent_commission_amount - @other_insurance.sub_agent_tds_amount
      end
    end

    # Calculate ambassador commission
    if @other_insurance.ambassador_commission_percentage.present?
      @other_insurance.ambassador_commission_amount = (net_premium * @other_insurance.ambassador_commission_percentage) / 100

      if @other_insurance.ambassador_tds_percentage.present?
        @other_insurance.ambassador_tds_amount = (@other_insurance.ambassador_commission_amount * @other_insurance.ambassador_tds_percentage) / 100
        @other_insurance.ambassador_after_tds_value = @other_insurance.ambassador_commission_amount - @other_insurance.ambassador_tds_amount
      end
    end

    # Calculate investor commission
    if @other_insurance.investor_commission_percentage.present?
      @other_insurance.investor_commission_amount = (net_premium * @other_insurance.investor_commission_percentage) / 100

      if @other_insurance.investor_tds_percentage.present?
        @other_insurance.investor_tds_amount = (@other_insurance.investor_commission_amount * @other_insurance.investor_tds_percentage) / 100
        @other_insurance.investor_after_tds_value = @other_insurance.investor_commission_amount - @other_insurance.investor_tds_amount
      end
    end
  end

  # Handle R2 document uploads for Other Insurance
  def handle_other_documents_r2_upload(other_insurance, main_policy_document = nil, documents = nil)
    # Handle main policy document upload using model method
    if main_policy_document.present?
      result = other_insurance.upload_main_policy_to_r2(main_policy_document)

      if result && result[:key] && !result[:error]
        Rails.logger.info "Successfully uploaded main policy document for Other Insurance ##{other_insurance.id}"
      else
        error_msg = result[:error] || "Unknown error"
        Rails.logger.error "Failed to upload main policy document for Other Insurance ##{other_insurance.id}: #{error_msg}"
      end
    end

    # Handle additional documents array
    if documents.present? && documents.is_a?(Array)
      documents.each_with_index do |file, index|
        next if file.blank? || !file.respond_to?(:original_filename)

        document = other_insurance.other_insurance_documents.build(
          document_type: 'Additional Document',
          title: "Additional Document #{index + 1}",
          description: "Additional document uploaded with policy"
        )

        upload_result = document.upload_to_r2(file)

        if upload_result.is_a?(Hash) && upload_result[:success]
          document.save!
          Rails.logger.info "Successfully uploaded additional document #{index + 1} for Other Insurance ##{other_insurance.id}"
        elsif upload_result.is_a?(Hash) && upload_result[:error]
          Rails.logger.error "Failed to upload additional document #{index + 1} for Other Insurance ##{other_insurance.id}: #{upload_result[:error]}"
        elsif upload_result == false
          error_messages = document.errors.full_messages.join(', ')
          Rails.logger.error "Failed to upload additional document #{index + 1} for Other Insurance ##{other_insurance.id}: Validation failed: #{error_messages}"
        else
          Rails.logger.error "Failed to upload additional document #{index + 1} for Other Insurance ##{other_insurance.id}: Unknown upload result: #{upload_result.inspect}"
        end
      end
    end

    return unless params[:other_insurance].present?

    # Handle legacy main policy document upload (for update method)
    if params[:other_insurance][:main_policy_document].present?
      file = params[:other_insurance][:main_policy_document]

      # Create OtherInsuranceDocument for main policy document
      document = other_insurance.other_insurance_documents.build(
        document_type: 'Policy Document',
        title: 'Main Policy Document',
        description: 'Primary policy document for this insurance'
      )

      upload_result = document.upload_to_r2(file)

      if upload_result.is_a?(Hash) && upload_result[:success]
        document.save!
        Rails.logger.info "Successfully uploaded main policy document for Other Insurance ##{other_insurance.id}"
      elsif upload_result.is_a?(Hash) && upload_result[:error]
        Rails.logger.error "Failed to upload main policy document for Other Insurance ##{other_insurance.id}: #{upload_result[:error]}"
      elsif upload_result == false
        error_messages = document.errors.full_messages.join(', ')
        Rails.logger.error "Failed to upload main policy document for Other Insurance ##{other_insurance.id}: Validation failed: #{error_messages}"
      else
        Rails.logger.error "Failed to upload main policy document for Other Insurance ##{other_insurance.id}: Unknown upload result: #{upload_result.inspect}"
      end
    end

    # Handle additional documents from dynamic form
    if params[:other_insurance][:other_insurance_documents_attributes].present?
      params[:other_insurance][:other_insurance_documents_attributes].each do |index, doc_params|
        next unless doc_params[:file].present? && doc_params[:document_type].present?

        file = doc_params[:file]

        document = other_insurance.other_insurance_documents.build(
          document_type: doc_params[:document_type],
          title: doc_params[:title].presence || "#{doc_params[:document_type]} Document",
          description: doc_params[:description].presence || "Uploaded #{doc_params[:document_type]} document"
        )

        upload_result = document.upload_to_r2(file)

        if upload_result.is_a?(Hash) && upload_result[:success]
          document.save!
          Rails.logger.info "Successfully uploaded document '#{document.title}' for Other Insurance ##{other_insurance.id}"
        elsif upload_result.is_a?(Hash) && upload_result[:error]
          Rails.logger.error "Failed to upload document '#{document.title}' for Other Insurance ##{other_insurance.id}: #{upload_result[:error]}"
        elsif upload_result == false
          error_messages = document.errors.full_messages.join(', ')
          Rails.logger.error "Failed to upload document '#{document.title}' for Other Insurance ##{other_insurance.id}: Validation failed: #{error_messages}"
        else
          Rails.logger.error "Failed to upload document '#{document.title}' for Other Insurance ##{other_insurance.id}: Unknown upload result: #{upload_result.inspect}"
        end
      end
    end

    # Handle documents uploaded through file fields (for backward compatibility)
    [:documents, :additional_documents, :policy_documents].each do |field|
      if params[:other_insurance][field].present?
        params[:other_insurance][field].each do |file|
          next unless file.present?

          # Determine document type based on field name
          document_type = case field
                         when :policy_documents
                           'Policy Document'
                         when :additional_documents
                           'Additional Document'
                         else
                           'Other'
                         end

          document = other_insurance.other_insurance_documents.build(
            document_type: document_type,
            title: "#{document_type} - #{file.original_filename}",
            description: "Uploaded #{document_type.downcase}"
          )

          upload_result = document.upload_to_r2(file)

          if upload_result.is_a?(Hash) && upload_result[:success]
            document.save!
            Rails.logger.info "Successfully uploaded #{field} document for Other Insurance ##{other_insurance.id}"
          elsif upload_result.is_a?(Hash) && upload_result[:error]
            Rails.logger.error "Failed to upload #{field} document for Other Insurance ##{other_insurance.id}: #{upload_result[:error]}"
          elsif upload_result == false
            error_messages = document.errors.full_messages.join(', ')
            Rails.logger.error "Failed to upload #{field} document for Other Insurance ##{other_insurance.id}: Validation failed: #{error_messages}"
          else
            Rails.logger.error "Failed to upload #{field} document for Other Insurance ##{other_insurance.id}: Unknown upload result: #{upload_result.inspect}"
          end
        end
      end
    end

  rescue => e
    Rails.logger.error "Error in handle_other_documents_r2_upload for Other Insurance ##{other_insurance&.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  # Extract uploaded documents data and files from nested attributes
  def extract_uploaded_documents_data
    uploaded_docs_data = []

    if params[:other_insurance] && params[:other_insurance][:uploaded_documents_attributes]
      params[:other_insurance][:uploaded_documents_attributes].each do |index, doc_params|
        next unless doc_params.is_a?(Hash)

        # Extract the file parameter
        file = doc_params.delete(:file) if doc_params[:file].present?

        # Only proceed if we have required fields
        next unless file && doc_params[:title].present? && doc_params[:document_type].present?

        uploaded_docs_data << {
          file: file,
          title: doc_params[:title],
          document_type: doc_params[:document_type],
          description: doc_params[:description]
        }
      end

      # Remove the uploaded_documents_attributes from params to prevent nested attribute processing
      params[:other_insurance].delete(:uploaded_documents_attributes)
    end

    uploaded_docs_data
  end

  # Handle uploaded documents through the Document model
  def handle_uploaded_documents_r2_upload(other_insurance, uploaded_documents_data)
    return unless uploaded_documents_data.present?

    uploaded_documents_data.each_with_index do |doc_data, index|
      begin
        # Create Document record
        document = other_insurance.uploaded_documents.build(
          title: doc_data[:title],
          document_type: doc_data[:document_type],
          description: doc_data[:description],
          uploaded_by: current_user&.email || 'admin'
        )

        # Upload file to R2
        upload_result = document.upload_to_r2(doc_data[:file])

        # Handle different return types from upload_to_r2:
        # - { success: true, ... } on successful upload
        # - { error: "..." } on upload failure
        # - false on validation errors or no file
        if upload_result.is_a?(Hash) && upload_result[:success]
          document.save!
          Rails.logger.info "Successfully uploaded document '#{doc_data[:title]}' for Other Insurance ##{other_insurance.id}"
        elsif upload_result.is_a?(Hash) && upload_result[:error]
          Rails.logger.error "Failed to upload document '#{doc_data[:title]}' for Other Insurance ##{other_insurance.id}: #{upload_result[:error]}"
        elsif upload_result == false
          # Document model returns false for validation errors - check document errors
          error_messages = document.errors.full_messages.join(', ')
          Rails.logger.error "Failed to upload document '#{doc_data[:title]}' for Other Insurance ##{other_insurance.id}: Validation failed: #{error_messages}"
        else
          Rails.logger.error "Failed to upload document '#{doc_data[:title]}' for Other Insurance ##{other_insurance.id}: Unknown upload result: #{upload_result.inspect}"
        end
      rescue => e
        Rails.logger.error "Error uploading document #{index + 1} for Other Insurance ##{other_insurance.id}: #{e.message}"
      end
    end
  rescue => e
    Rails.logger.error "Error in handle_uploaded_documents_r2_upload for Other Insurance ##{other_insurance&.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

end
