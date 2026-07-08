class Admin::LifeInsurancesController < Admin::ApplicationController
  include ConfigurablePagination
  before_action :set_life_insurance, only: [:show, :edit, :update, :destroy, :commission_details, :renew, :create_renewal]

  # GET /admin/insurance/life
  def index
    @life_insurances = LifeInsurance.includes(:customer, :sub_agent, :agency_code, :broker, :renewal_policy)

    # Tab-based filtering for DrWise vs Non-DrWise policies
    @current_tab = params[:tab] || 'drwise'

    case @current_tab
    when 'drwise'
      @life_insurances = @life_insurances.where(
        is_admin_added: true, is_customer_added: false, is_agent_added: false
      )
    when 'non_drwise'
      @life_insurances = @life_insurances.where(
        '(is_customer_added = ? AND is_admin_added = ? AND is_agent_added = ?) OR (is_agent_added = ? AND is_customer_added = ? AND is_admin_added = ?)',
        true, false, false, true, false, false
      )
    end

    # Basic search
    if params[:search].present?
      @life_insurances = @life_insurances.search_life_policies(params[:search])
    end

    # Basic status filter
    case params[:status]
    when 'active'        then @life_insurances = @life_insurances.active
    when 'expired'       then @life_insurances = @life_insurances.expired
    when 'expiring_soon' then @life_insurances = @life_insurances.expiring_soon
    end

    # ── Advanced filters ──────────────────────────────────────────
    if params[:company].present?
      @life_insurances = @life_insurances.where(insurance_company_name: params[:company])
    end

    if params[:sub_agent_id].present?
      @life_insurances = @life_insurances.where(sub_agent_id: params[:sub_agent_id])
    end

    if params[:policy_type].present?
      @life_insurances = @life_insurances.where(policy_type: params[:policy_type])
    end

    if params[:payment_mode].present?
      @life_insurances = @life_insurances.where(payment_mode: params[:payment_mode])
    end

    if params[:from_date].present?
      @life_insurances = @life_insurances.where('policy_start_date >= ?', Date.parse(params[:from_date]))
    end

    if params[:to_date].present?
      @life_insurances = @life_insurances.where('policy_start_date <= ?', Date.parse(params[:to_date]))
    end
    # ─────────────────────────────────────────────────────────────

    # Calculate statistics for current tab (before pagination)
    calculate_tab_statistics

    @life_insurances = paginate_records(@life_insurances.order(policy_start_date: :desc))

    # Filter dropdowns — 1 pluck instead of 2 queries + avoid loading all sub_agents
    life_dropdown_data = LifeInsurance.pluck(:insurance_company_name, :sub_agent_id)
    @filter_companies     = life_dropdown_data.map { |r| r[0] }.compact.uniq.reject(&:blank?).sort
    life_sub_agent_ids    = life_dropdown_data.map { |r| r[1] }.compact.uniq
    @filter_sub_agents    = SubAgent.where(id: life_sub_agent_ids).order(:first_name, :last_name)
    @filter_policy_types  = LifeInsurance::POLICY_TYPES
    @filter_payment_modes = LifeInsurance::PAYMENT_MODES
  end

  # GET /admin/insurance/life/1
  def show
  end

  # GET /admin/insurance/life/new
  def new
    @life_insurance = LifeInsurance.new
    set_form_data

    # Set default commission percentage from system settings
    @life_insurance.main_agent_commission_percentage = SystemSetting.default_main_agent_commission

    # Pre-fill customer data if coming from customer page
    if params[:customer_id].present?
      @selected_customer = Customer.find(params[:customer_id])
      @life_insurance.customer_id = @selected_customer.id

      # Auto-select customer's existing affiliate if they have one
      if @selected_customer.affiliate.present?
        @life_insurance.sub_agent_id = @selected_customer.affiliate.id
        @auto_select_affiliate = @selected_customer.affiliate.id
      else
        # Set 'Self' as default affiliate (no sub_agent)
        @auto_select_affiliate = 'self'
      end

      # Auto-populate family members as policy holder options
      @customer_family_members = @selected_customer.family_members.includes(:customer)
    end
  end

  # GET /admin/insurance/life/1/edit
  def edit
    set_form_data

    # Load customer family members for policy holder dropdown if customer is selected
    if @life_insurance.customer_id.present?
      @selected_customer = @life_insurance.customer
      @customer_family_members = @selected_customer.family_members.includes(:customer)
    else
      @customer_family_members = []
    end

    # Set auto_select_affiliate for the form
    if @life_insurance.sub_agent_id.present?
      @auto_select_affiliate = @life_insurance.sub_agent_id
      # Ensure the current sub_agent is included in the dropdown even if inactive
      unless @sub_agents.exists?(id: @life_insurance.sub_agent_id)
        current_sub_agent = SubAgent.find_by(id: @life_insurance.sub_agent_id)
        @sub_agents = ([current_sub_agent].compact + @sub_agents.to_a).uniq(&:id)
      end
    elsif @selected_customer&.affiliate.present?
      @auto_select_affiliate = @selected_customer.affiliate.id
    else
      @auto_select_affiliate = 'self'
    end

    # For broking type policies, determine the correct agency_code selection
    # Since we store broker_id but the form expects broker_X format for broking
    if @life_insurance.broker_code_type == 'broking' && @life_insurance.broker_id.present?
      # Find the broker code that matches this broker
      broker_code = BrokerCode.find_by(broker_id: @life_insurance.broker_id)
      if broker_code
        @selected_broker_code = "broker_#{broker_code.id}"
      end
    end
  end

  # POST /admin/insurance/life
  def create
    processed_params = process_broker_params(life_insurance_params)
    # Remove documents and uploaded_documents_attributes from processed_params since we handle them separately
    processed_params_without_docs = processed_params.except(:uploaded_documents_attributes, :documents)
    @life_insurance = LifeInsurance.new(processed_params_without_docs)

    # Set admin tracking fields for policies created from admin panel
    @life_insurance.policy_added_by_admin = true
    @life_insurance.is_admin_added = true
    @life_insurance.is_customer_added = false
    @life_insurance.is_agent_added = false

    # Auto-set affiliate from customer if not already set
    if @life_insurance.sub_agent_id.blank? && @life_insurance.customer_id.present?
      customer = Customer.find(@life_insurance.customer_id)
      if customer.sub_agent_id.present?
        @life_insurance.sub_agent_id = customer.sub_agent_id
      elsif customer.lead_id.present?
        lead = Lead.find_by(lead_id: customer.lead_id)
        @life_insurance.sub_agent_id = lead.affiliate_id if lead&.affiliate_id.present?
      end
    end

    set_distributor_from_affiliate(@life_insurance)

    begin
      # Ensure distributor is set before saving (double-check)
      set_distributor_from_affiliate(@life_insurance)

      if @life_insurance.save
        # Handle R2 main policy document upload
        handle_main_policy_r2_upload(@life_insurance) if params[:life_insurance][:main_policy_document].present?

        # Handle additional document uploads to R2
        handle_additional_documents_r2_upload(@life_insurance)

        redirect_to admin_life_insurances_path,
                    notice: 'Life insurance policy was successfully created.'
      else
        set_form_data
        preserve_form_state_on_error
        render :new, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotUnique => e
      if e.message.include?('policy_number')
        @life_insurance.errors.add(:policy_number, 'has already been taken')
      else
        @life_insurance.errors.add(:base, 'A record with similar details already exists')
      end
      set_form_data
      preserve_form_state_on_error
      render :new, status: :unprocessable_entity
    rescue ActiveRecord::InvalidForeignKey
      @life_insurance.errors.add(:base, 'Selected agency code or related record no longer exists. Please reselect.')
      set_form_data
      preserve_form_state_on_error
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /admin/insurance/life/1
  def update
    # Handle R2 main policy document deletion
    if params[:delete_main_policy_document] == 'true'
      if @life_insurance.has_main_policy_r2_document?
        @life_insurance.delete_main_policy_from_r2
        redirect_to edit_admin_life_insurance_path(@life_insurance), notice: 'Main policy document was successfully deleted.'
        return
      else
        redirect_to edit_admin_life_insurance_path(@life_insurance), alert: 'No main policy document to delete.'
        return
      end
    end

    processed_params = process_broker_params(life_insurance_params)
    # Remove uploaded_documents_attributes and documents from processed_params since we handle them separately
    processed_params_without_docs = processed_params.except(:uploaded_documents_attributes, :documents)
    @life_insurance.assign_attributes(processed_params_without_docs)
    set_distributor_from_affiliate(@life_insurance)

    begin
      if @life_insurance.save
        # Handle R2 main policy document upload
        handle_main_policy_r2_upload(@life_insurance) if params[:life_insurance][:main_policy_document].present?

        # Handle additional document uploads to R2
        handle_additional_documents_r2_upload(@life_insurance)

        redirect_to admin_life_insurances_path,
                    notice: 'Life insurance policy was successfully updated.'
      else
        set_form_data
        render :edit, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotUnique => e
      if e.message.include?('policy_number')
        @life_insurance.errors.add(:policy_number, 'has already been taken')
      else
        @life_insurance.errors.add(:base, 'A record with similar details already exists')
      end
      set_form_data
      render :edit, status: :unprocessable_entity
    rescue ActiveRecord::InvalidForeignKey
      @life_insurance.errors.add(:base, 'Selected agency code or related record no longer exists. Please reselect.')
      set_form_data
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/insurance/life/1
  def destroy
    policy_number = @life_insurance.policy_number
    customer_name = @life_insurance.customer&.display_name

    begin
      ActiveRecord::Base.transaction do
        # 1. Delete commission payouts for this life insurance
        CommissionPayout.where(policy_type: 'life', policy_id: @life_insurance.id).destroy_all

        # 2. Delete main payouts for this life insurance
        Payout.where(policy_type: 'life', policy_id: @life_insurance.id).destroy_all

        # 3. Delete lead record if it was created for this policy
        if @life_insurance.lead_id.present?
          lead = Lead.find_by(lead_id: @life_insurance.lead_id)
          if lead && lead.policy_created_id == @life_insurance.id
            lead.destroy
          end
        end

        # 4. Delete policy documents from R2 and database
        @life_insurance.policy_documents_records.each do |doc|
          # Delete from R2 if file key exists
          if doc.r2_file_key.present?
            R2Service.delete_file(doc.r2_file_key) rescue Rails.logger.warn("Failed to delete R2 file: #{doc.r2_file_key}")
          end
        end

        # 5. Delete main policy document from R2 if exists
        if @life_insurance.has_main_policy_r2_document?
          @life_insurance.delete_main_policy_from_r2 rescue Rails.logger.warn("Failed to delete main policy from R2")
        end

        # 6. Delete uploaded documents from R2
        @life_insurance.uploaded_documents.each do |doc|
          if doc.respond_to?(:file) && doc.file.attached?
            doc.file.purge rescue Rails.logger.warn("Failed to purge uploaded document")
          end
        end

        # 7. Handle renewal relationships
        if @life_insurance.renewal_policy_id.present?
          renewal_policy = LifeInsurance.find_by(id: @life_insurance.renewal_policy_id)
          if renewal_policy
            renewal_policy.update!(original_policy_id: nil)
          end
        end

        # If this is a renewal policy, clear the original policy's renewal reference
        if @life_insurance.original_policy_id.present?
          original_policy = LifeInsurance.find_by(id: @life_insurance.original_policy_id)
          if original_policy
            original_policy.update!(renewal_policy_id: nil, is_renewed: false)
          end
        end

        # 8. Delete the life insurance record (this will cascade to dependent associations)
        @life_insurance.destroy!
      end

      redirect_to admin_life_insurances_path,
                  notice: "Life insurance policy #{policy_number} for #{customer_name} and all associated data were successfully deleted."

    rescue => e
      Rails.logger.error "Failed to delete life insurance #{@life_insurance.id}: #{e.message}"
      redirect_to admin_life_insurances_path,
                  alert: "Failed to delete life insurance policy. Error: #{e.message}"
    end
  end

  # Policy holder options method removed - now using simple text input


  # GET /admin/insurance/life/1/commission_details
  def commission_details
    # This will render the commission details view
  end

  # API endpoint for getting brokers by insurance company
  def brokers_by_company
    company_name = params[:company_name]
    brokers = if company_name.present?
                # First get insurance_company by name, then get brokers
                insurance_company = InsuranceCompany.find_by(name: company_name)
                if insurance_company
                  Broker.where(insurance_company: insurance_company).active.order(:name)
                else
                  Broker.none
                end
              else
                Broker.none
              end

    render json: {
      brokers: brokers.map { |b| { id: b.id, name: b.name } }
    }
  end

  # API endpoint for getting agency codes by broker
  def agency_codes_by_broker
    broker_id = params[:broker_id]
    agency_codes = if broker_id.present?
                     AgencyCode.where(broker_id: broker_id, insurance_type: 'Life').order(:code)
                   else
                     AgencyCode.none
                   end

    render json: {
      agency_codes: agency_codes.map { |a| { id: a.id, name: "#{a.company_name} - #{a.code}" } }
    }
  end

  # API endpoint for getting all agency codes (for Direct selection)
  def all_agency_codes
    agency_codes = AgencyCode.where(
      "insurance_type = ? OR insurance_type = ? OR insurance_type IS NULL",
      'Life Insurance', 'All'
    ).order(:agent_name, :code)

    render json: {
      success: true,
      agents: agency_codes.map { |a| {
        id: a.id,
        agent_name: a.agent_name,
        code: a.code,
        company_name: a.company_name
      } }
    }
  end

  # API endpoint for getting all brokers (for Broking selection)
  def all_brokers
    brokers = Broker.active.order(:name)

    render json: {
      brokers: brokers.map { |b| { id: b.id, name: b.name } }
    }
  end

  # API endpoint for getting customer family members for policy holder options
  def customer_family_members
    customer_id = params[:customer_id]

    if customer_id.present?
      begin
        customer = Customer.find(customer_id)
        family_members = customer.family_members.includes(:customer)

        # Build policy holder options
        policy_holder_options = [{ value: 'Self', text: 'Self' }]

        family_members.each do |member|
          # Only add if member has a valid name and it's not empty/numeric only
          if member.name.present? && member.name.strip.length > 0 && !member.name.strip.match?(/^\d+$/)
            display_name = "#{member.name} (#{member.relationship.humanize})"
            # Use name as value, display name as text - this ensures the database stores just the name
            policy_holder_options << {
              value: member.name,
              text: display_name
            }
          end
        end

        render json: {
          success: true,
          options: policy_holder_options,
          customer_name: customer.display_name
        }
      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          message: 'Customer not found',
          options: [{ value: 'Self', text: 'Self' }]
        }
      end
    else
      render json: {
        success: false,
        message: 'Customer ID is required',
        options: [{ value: 'Self', text: 'Self' }]
      }
    end
  end

  # GET /admin/insurance/life/:id/renew
  def renew
    # Check if policy expires within 60 days
    if @life_insurance.policy_end_date.blank? || @life_insurance.policy_end_date > 60.days.from_now
      redirect_to admin_life_insurances_path, alert: "This policy is not eligible for renewal yet."
      return
    end

    # Create a new life insurance object with pre-filled data from the original policy
    @renewed_policy = @life_insurance.dup

    # Clear fields that should be reset for renewal
    @renewed_policy.policy_number = nil
    @renewed_policy.policy_booking_date = nil
    @renewed_policy.policy_start_date = nil
    @renewed_policy.policy_end_date = nil
    @renewed_policy.risk_start_date = nil
    @renewed_policy.policy_type = 'Renewal'
    @renewed_policy.created_at = nil
    @renewed_policy.updated_at = nil
    @renewed_policy.id = nil

    # Set default dates for renewal
    @renewed_policy.policy_booking_date = Date.current
    @renewed_policy.policy_start_date = @life_insurance.policy_end_date + 1.day
    @renewed_policy.policy_end_date = @renewed_policy.policy_start_date + 1.year
    @renewed_policy.risk_start_date = @renewed_policy.policy_start_date

    # Store original policy for reference
    @original_policy = @life_insurance

    # Set default commission values if they are zero (common for old policies)
    if @renewed_policy.main_agent_commission_percentage.to_f.zero?
      @renewed_policy.main_agent_commission_percentage = 15.0 # Default 15% for main agent
    end

    # Ensure sub-agent commission has a default if zero
    if @renewed_policy.sub_agent_commission_percentage.to_f.zero?
      @renewed_policy.sub_agent_commission_percentage = 2.0
    end

    # Ensure ambassador commission has a default if zero
    if @renewed_policy.ambassador_commission_percentage.to_f.zero?
      @renewed_policy.ambassador_commission_percentage = 2.0
    end

    # Ensure investor commission has a default if zero
    if @renewed_policy.investor_commission_percentage.to_f.zero?
      @renewed_policy.investor_commission_percentage = 2.0
    end

    # Ensure company expenses has a default if zero
    if @renewed_policy.company_expenses_percentage.to_f.zero?
      @renewed_policy.company_expenses_percentage = 2.0
    end

    # Get available options for dropdowns
    set_form_data

    # Load customer family members for policy holder dropdown
    if @renewed_policy.customer_id.present?
      @customer_family_members = Customer.find(@renewed_policy.customer_id).family_members.includes(:customer)
    else
      @customer_family_members = []
    end

    # Ensure distributor is set for affiliate
    set_distributor_from_affiliate(@renewed_policy)
  end

  # POST /admin/insurance/life/:id/create_renewal
  def create_renewal
    # Check if policy expires within 60 days
    if @life_insurance.policy_end_date.blank? || @life_insurance.policy_end_date > 60.days.from_now
      redirect_to admin_life_insurances_path, alert: "This policy is not eligible for renewal yet."
      return
    end

    # Create new policy with renewal data
    processed_params = process_broker_params(life_insurance_params)
    @renewed_policy = LifeInsurance.new(processed_params)
    @renewed_policy.policy_type = 'Renewal'

    # Set admin added flags for renewal (same as original)
    @renewed_policy.is_admin_added = @life_insurance.is_admin_added
    @renewed_policy.is_customer_added = @life_insurance.is_customer_added
    @renewed_policy.is_agent_added = @life_insurance.is_agent_added

    # Ensure distributor is set from affiliate before saving
    set_distributor_from_affiliate(@renewed_policy)

    if @renewed_policy.save
      # Handle R2 main policy document upload for renewal
      handle_main_policy_r2_upload(@renewed_policy) if params[:life_insurance][:main_policy_document].present?

      # Handle additional document uploads to R2 for renewal
      handle_additional_documents_r2_upload(@renewed_policy)

      # Set renewal relationships
      @renewed_policy.update!(original_policy_id: @life_insurance.id)
      @life_insurance.update!(renewal_policy_id: @renewed_policy.id, is_renewed: true)

      # Update commission calculations (if needed for other fields)
      set_distributor_from_affiliate(@renewed_policy)
      redirect_to admin_life_insurance_path(@renewed_policy),
                  notice: 'Life insurance policy was successfully created.'
    else
      @original_policy = @life_insurance
      set_form_data

      # Load customer family members for policy holder dropdown on error
      if @renewed_policy.customer_id.present?
        @customer_family_members = Customer.find(@renewed_policy.customer_id).family_members.includes(:customer)
      else
        @customer_family_members = []
      end

      render :renew, status: :unprocessable_entity
    end
  end

  # API endpoints for dynamic dropdowns
  def agency_codes_for_broker_type
    broker_type = params[:broker_type]

    if broker_type == 'direct'
      # Load agency codes for Life Insurance
      agency_codes = AgencyCode.where(insurance_type: 'Life Insurance')
                               .select(:id, :agent_name, :code, :company_name)

      render json: {
        success: true,
        data: agency_codes.map { |ac|
          {
            id: ac.id,
            text: "#{ac.agent_name} (#{ac.code})",
            company_name: ac.company_name
          }
        }
      }
    elsif broker_type == 'broking'
      # Load broker codes with associated broker info
      broker_codes = BrokerCode.includes(:broker).active

      render json: {
        success: true,
        data: broker_codes.map { |bc|
          {
            id: "broker_#{bc.broker_id}",
            text: "#{bc.broker.name} (#{bc.broker_code})",
            broker_id: bc.broker_id
          }
        }
      }
    else
      render json: { success: false, message: 'Invalid broker type' }
    end
  end

  def insurance_companies_for_type
    # Get life insurance companies from model constant
    begin
      companies = LifeInsurance.life_insurance_companies.map { |company| company[:name] || company['name'] }
    rescue => e
      Rails.logger.error "Error loading life insurance companies: #{e.message}"
      companies = [
        'ICICI Prudential Life Insurance Co Ltd',
        'SBI Life Insurance Co Ltd',
        'LIC India',
        'HDFC Standard Life Insurance Co Ltd',
        'Max Life Insurance Co Ltd',
        'Bajaj Allianz Life Insurance Co Ltd'
      ]
    end

    render json: {
      success: true,
      data: companies.sort_by(&:downcase).map { |name| { id: name, text: name } }
    }
  end

  # API endpoint to load customer nominees for auto-population
  def load_customer_nominees
    customer_id = params[:customer_id]

    if customer_id.present?
      begin
        customer = Customer.find(customer_id)
        family_members = customer.family_members.includes(:customer)

        # Build nominee options from family members
        nominee_options = []
        debug_info = []

        family_members.each do |member|
          # Debug info for each family member
          debug_member = {
            name: member.name,
            name_present: member.name.present?,
            name_stripped: member.name&.strip,
            name_length: member.name&.strip&.length,
            is_number: member.name&.strip&.match?(/^\d+$/),
            relationship: member.relationship,
            age: member.age
          }
          debug_info << debug_member

          if member.name.present? && member.name.strip.length > 0 && !member.name.strip.match?(/^\d+$/)
            nominee_options << {
              nominee_name: member.name,
              relationship: member.relationship&.downcase || 'other',
              age: member.age || 0
            }
          end
        end

        # If no valid family member nominees, check customer's direct nominee fields
        if nominee_options.empty? && customer.nominee_name.present?
          # Calculate age from date of birth if available
          age = if customer.nominee_date_of_birth.present?
                  Date.current.year - customer.nominee_date_of_birth.year
                else
                  0
                end

          nominee_options << {
            nominee_name: customer.nominee_name,
            relationship: customer.nominee_relation&.downcase || 'other',
            age: age
          }

          debug_info << {
            source: 'customer_direct_nominee',
            name: customer.nominee_name,
            relationship: customer.nominee_relation,
            date_of_birth: customer.nominee_date_of_birth,
            calculated_age: age
          }
        end

        render json: {
          success: true,
          nominees: nominee_options,
          customer_name: customer.display_name,
          debug: {
            total_family_members: family_members.count,
            valid_nominees_from_family: nominee_options.count { |n| !debug_info.any? { |d| d[:source] == 'customer_direct_nominee' } },
            valid_nominees_from_customer: nominee_options.count { |n| debug_info.any? { |d| d[:source] == 'customer_direct_nominee' } },
            total_valid_nominees: nominee_options.count,
            family_members_debug: debug_info.reject { |d| d[:source] == 'customer_direct_nominee' },
            customer_nominee_debug: debug_info.select { |d| d[:source] == 'customer_direct_nominee' }
          }
        }
      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          message: 'Customer not found',
          nominees: []
        }
      rescue => e
        render json: {
          success: false,
          message: "Error: #{e.message}",
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

  # GET /admin/insurance/life/download
  def download
    format_type = params[:format_type]
    scope = build_life_filtered_scope.order(created_at: :desc)

    case format_type
    when 'csv'
      send_data generate_life_csv(scope),
                filename: "life_insurance_#{Date.current}.csv", type: 'text/csv'
    when 'excel'
      send_data generate_life_excel(scope),
                filename: "life_insurance_#{Date.current}.xlsx",
                type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    else
      redirect_to admin_life_insurances_path, alert: 'Invalid download format.'
    end
  end

  private

  def build_life_filtered_scope
    scope = LifeInsurance.includes(:customer, :sub_agent, :broker)
    current_tab = params[:tab] || 'drwise'
    case current_tab
    when 'drwise'
      scope = scope.where(is_admin_added: true, is_customer_added: false, is_agent_added: false)
    when 'non_drwise'
      scope = scope.where(
        '(is_customer_added = ? AND is_admin_added = ? AND is_agent_added = ?) OR (is_agent_added = ? AND is_customer_added = ? AND is_admin_added = ?)',
        true, false, false, true, false, false
      )
    end
    scope = scope.search_life_policies(params[:search])   if params[:search].present?
    case params[:status]
    when 'active'        then scope = scope.active
    when 'expired'       then scope = scope.expired
    when 'expiring_soon' then scope = scope.expiring_soon
    end
    scope = scope.where(insurance_company_name: params[:company])    if params[:company].present?
    scope = scope.where(sub_agent_id: params[:sub_agent_id])         if params[:sub_agent_id].present?
    scope = scope.where(policy_type: params[:policy_type])           if params[:policy_type].present?
    scope = scope.where(payment_mode: params[:payment_mode])         if params[:payment_mode].present?
    scope = scope.where('policy_start_date >= ?', Date.parse(params[:from_date])) if params[:from_date].present?
    scope = scope.where('policy_start_date <= ?', Date.parse(params[:to_date]))   if params[:to_date].present?
    scope
  end

  def generate_life_csv(records)
    require 'csv'
    CSV.generate(headers: true) do |csv|
      csv << %w[ID PolicyNumber PolicyType CustomerName CustomerEmail InsuranceCompany
                SumAssured TotalPremium NetPremium PaymentMode PolicyStartDate
                PolicyEndDate PolicyHolder PlanName PolicyTerm Status Source
                Affiliate Broker BookingDate CreatedAt]
      records.find_each do |p|
        source = if p.is_admin_added? then 'Admin' elsif p.is_agent_added? then 'Agent' elsif p.is_customer_added? then 'Customer' else 'Unknown' end
        csv << [p.id, p.policy_number, p.policy_type, p.customer&.display_name, p.customer&.email,
                p.insurance_company_name, p.sum_insured, p.total_premium, p.net_premium,
                p.payment_mode, p.policy_start_date, p.policy_end_date, p.policy_holder,
                p.plan_name, p.policy_term, p.status, source, p.sub_agent&.display_name,
                p.broker&.name, p.policy_booking_date, p.created_at.strftime('%Y-%m-%d %H:%M:%S')]
      end
    end
  end

  def generate_life_excel(records)
    require 'caxlsx'
    package = Axlsx::Package.new
    wb = package.workbook
    hdr = wb.styles.add_style(bg_color: '1565C0', fg_color: 'FFFFFF', b: true, alignment: { horizontal: :center })
    row = wb.styles.add_style(alignment: { horizontal: :left })
    wb.add_worksheet(name: 'Life Insurance') do |sheet|
      sheet.add_row %w[ID PolicyNumber PolicyType CustomerName CustomerEmail InsuranceCompany
                       SumAssured TotalPremium NetPremium PaymentMode PolicyStartDate
                       PolicyEndDate PolicyHolder PlanName PolicyTerm Status Source
                       Affiliate Broker BookingDate CreatedAt], style: hdr
      records.find_each do |p|
        source = if p.is_admin_added? then 'Admin' elsif p.is_agent_added? then 'Agent' elsif p.is_customer_added? then 'Customer' else 'Unknown' end
        sheet.add_row [p.id, p.policy_number, p.policy_type, p.customer&.display_name, p.customer&.email,
                       p.insurance_company_name, p.sum_insured.to_f, p.total_premium.to_f, p.net_premium.to_f,
                       p.payment_mode, p.policy_start_date&.to_s, p.policy_end_date&.to_s, p.policy_holder,
                       p.plan_name, p.policy_term, p.status, source, p.sub_agent&.display_name,
                       p.broker&.name, p.policy_booking_date&.to_s, p.created_at.strftime('%Y-%m-%d %H:%M:%S')], style: row
      end
    end
    package.to_stream.read
  end

  def set_life_insurance
    @life_insurance = LifeInsurance.includes(:customer, :sub_agent, :agency_code, :broker, :life_insurance_nominees).find(params[:id])
  end

  def set_form_data
    @customers = Customer.active.order(:first_name, :last_name, :company_name)
    @sub_agents = SubAgent.active.order(:first_name, :last_name)
    @distributors = Distributor.active.order(:first_name, :last_name)
    @investors = Investor.active.order(:first_name, :last_name)

    # Load agency codes for Life Insurance (include both specific and general codes)
    @agency_codes = AgencyCode.where(
      "insurance_type = ? OR insurance_type = ? OR insurance_type IS NULL",
      'Life Insurance', 'All'
    ).order(:agent_name, :code)

    # Load brokers if needed
    @brokers = Broker.active.order(:name)

    # Load life insurance companies from the database
    begin
      # Get life insurance companies from the InsuranceCompany model
      @insurance_companies = InsuranceCompany.where("name ILIKE ?", "%life%")
                                           .or(InsuranceCompany.where("name ILIKE ?", "%LIC%"))
                                           .distinct
                                           .order(:name)
                                           .pluck(:name)

      # Fallback to constants if database is empty
      if @insurance_companies.empty?
        @insurance_companies = LifeInsurance.life_insurance_companies.map { |company| company[:name] || company['name'] }.sort
      end

      # Ensure current life insurance company is in the options (for edit forms)
      if defined?(@life_insurance) && @life_insurance&.insurance_company_name.present?
        unless @insurance_companies.include?(@life_insurance.insurance_company_name)
          @insurance_companies << @life_insurance.insurance_company_name
          @insurance_companies.sort!
        end
      end
    rescue => e
      Rails.logger.error "Error loading life insurance companies: #{e.message}"
      @insurance_companies = [
        'ICICI Prudential Life Insurance Co Ltd',
        'SBI Life Insurance Co Ltd',
        'LIC India',
        'HDFC Standard Life Insurance Co Ltd',
        'Max Life Insurance Co Ltd',
        'Bajaj Allianz Life Insurance Co Ltd'
      ]
    end

    @policy_types = LifeInsurance::POLICY_TYPES
    @payment_modes = LifeInsurance::PAYMENT_MODES
    @relationships = LifeInsurance::RELATIONSHIPS
    @account_types = LifeInsurance::ACCOUNT_TYPES
    @document_types = LifeInsurance::DOCUMENT_TYPES
  end

  def preserve_form_state_on_error
    # Load customer family members if a customer was selected
    if @life_insurance.customer_id.present?
      begin
        customer = Customer.find(@life_insurance.customer_id)
        @customer_family_members = customer.family_members.includes(:customer)
        @selected_customer = customer
      rescue ActiveRecord::RecordNotFound
        @customer_family_members = []
        @selected_customer = nil
      end
    else
      @customer_family_members = []
      @selected_customer = nil
    end

    # Set affiliate selection state for Select2 dropdown
    if @life_insurance.sub_agent_id.present?
      @auto_select_affiliate = @life_insurance.sub_agent_id
    else
      @auto_select_affiliate = 'self'
    end

    # Set flag to preserve form state in JavaScript
    @has_validation_errors = @life_insurance.errors.any?
    @preserve_selections = true

    # For broking type policies, determine the correct agency_code selection
    # Since we store broker_id but the form expects broker_X format for broking
    if @life_insurance.broker_code_type == 'broking' && @life_insurance.broker_id.present?
      # Find the broker code that matches this broker
      broker_code = BrokerCode.find_by(broker_id: @life_insurance.broker_id)
      if broker_code
        @selected_broker_code = "broker_#{broker_code.id}"
      end
    end

    # Store selected values for JavaScript to use
    @selected_values = {
      customer_id: @life_insurance.customer_id,
      sub_agent_id: @life_insurance.sub_agent_id,
      policy_holder: @life_insurance.policy_holder,
      broker_code_type: @life_insurance.broker_code_type,
      agency_code_id: @life_insurance.broker_code_type == 'broking' ? @selected_broker_code : @life_insurance.agency_code_id,
      insurance_company_name: @life_insurance.insurance_company_name,
      selected_broker_code: @selected_broker_code
    }
  end

  def process_broker_params(params)
    # Handle agency_code_id when it contains broker_X format
    if params[:agency_code_id].present? && params[:agency_code_id].start_with?('broker_')
      # Extract broker code ID from broker_X format
      broker_code_id = params[:agency_code_id].gsub('broker_', '').to_i

      # Find the broker code and set the actual broker_id
      if broker_code_id > 0
        broker_code = BrokerCode.find_by(id: broker_code_id)
        if broker_code
          params[:broker_id] = broker_code.broker_id
          params[:agency_code_id] = nil
          Rails.logger.info "Processed broker_#{broker_code_id} -> broker_id: #{broker_code.broker_id} (#{broker_code.broker.name})"
        else
          Rails.logger.warn "BrokerCode with ID #{broker_code_id} not found"
          params[:broker_id] = nil
          params[:agency_code_id] = nil
        end
      end
    end

    params
  end

  def life_insurance_params
    params.require(:life_insurance).permit(
      :customer_id, :sub_agent_id, :distributor_id, :agency_code_id, :broker_id, :broker_code_type,
      :policy_holder, :insured_name, :insurance_company_name, :insurance_company_code, :policy_type,
      :payment_mode, :policy_number, :policy_booking_date, :policy_start_date,
      :policy_end_date, :risk_start_date, :policy_term, :premium_payment_term,
      :plan_name, :sum_insured, :sum_insured_text, :net_premium, :first_year_gst_percentage,
      :second_year_gst_percentage, :third_year_gst_percentage, :total_premium,
      :nominee_name, :nominee_relationship, :nominee_age, :bank_name,
      :account_type, :account_number, :ifsc_code, :account_holder_name,
      :reference_by_name, :broker_name, :bonus, :fund, :extra_note,
      :main_agent_commission_percentage, :commission_amount, :tds_percentage,
      :tds_amount, :after_tds_value, :installment_autopay_start_date,
      :installment_autopay_end_date, :active,
      # Renewal tracking fields
      :original_policy_id, :renewal_policy_id, :is_renewed,
      # New commission fields - All commission details
      :sub_agent_commission_percentage, :sub_agent_commission_amount, :sub_agent_tds_percentage, :sub_agent_tds_amount, :sub_agent_after_tds_value,
      :distributor_commission_percentage, :distributor_commission_amount, :distributor_tds_percentage, :distributor_tds_amount, :distributor_after_tds_value,
      :ambassador_commission_percentage, :ambassador_commission_amount, :ambassador_tds_percentage, :ambassador_tds_amount, :ambassador_after_tds_value,
      :investor_commission_percentage, :investor_commission_amount, :investor_tds_percentage, :investor_tds_amount, :investor_after_tds_value,
      :main_income_percentage, :main_income_amount,
      # Company expenses and profit fields
      :company_expenses_percentage, :company_expenses_amount, :total_distribution_percentage,
      :profit_percentage, :profit_amount,
      # R2 document upload fields
      :main_policy_document, documents: [],
      uploaded_documents_attributes: [:id, :title, :description, :document_type, :document_file, :uploaded_by, :_destroy],
      life_insurance_documents_attributes: [:id, :document_type, :title, :description, :r2_file_key, :r2_filename, :r2_content_type, :r2_file_size, :_destroy],
      life_insurance_nominees_attributes: [:id, :nominee_name, :relationship, :age, :share_percentage, :_destroy]
    )
  end

  def set_distributor_from_affiliate(insurance_record)
    # If affiliate is selected but distributor is not set, auto-assign distributor
    if insurance_record.sub_agent_id.present? && insurance_record.distributor_id.blank?
      sub_agent = SubAgent.find_by(id: insurance_record.sub_agent_id)

      if sub_agent
        # Use direct distributor relationship first, then fall back to assignment
        distributor_id = sub_agent.distributor_id || sub_agent.assigned_distributor&.id

        if distributor_id.present?
          insurance_record.distributor_id = distributor_id
          Rails.logger.info "Set distributor_id #{distributor_id} from sub_agent #{sub_agent.id}"
        else
          Rails.logger.warn "No distributor found for sub_agent #{sub_agent.id} (#{sub_agent.display_name})"
          # If no distributor is found, use a default one or the first active distributor
          default_distributor = Distributor.active.first
          if default_distributor
            insurance_record.distributor_id = default_distributor.id
            Rails.logger.info "Using default distributor #{default_distributor.id} for sub_agent #{sub_agent.id}"
          else
            Rails.logger.error "No active distributors found in the system"
          end
        end
      else
        Rails.logger.error "SubAgent with id #{insurance_record.sub_agent_id} not found"
      end
    end
  rescue StandardError => e
    # Log error but don't fail the form submission
    Rails.logger.error "Failed to set distributor from affiliate: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  def calculate_tab_statistics
    # Single query replaces 6 separate count/sum queries
    row = ActiveRecord::Base.connection.execute(<<~SQL).first
      SELECT
        COUNT(*) FILTER (WHERE is_admin_added AND NOT is_customer_added AND NOT is_agent_added)                                                              AS drwise_count,
        COUNT(*) FILTER (WHERE (is_customer_added AND NOT is_admin_added AND NOT is_agent_added) OR (is_agent_added AND NOT is_customer_added AND NOT is_admin_added)) AS non_drwise_count,
        COALESCE(SUM(total_premium) FILTER (WHERE is_admin_added AND NOT is_customer_added AND NOT is_agent_added), 0)                                       AS drwise_premium,
        COALESCE(SUM(sum_insured)   FILTER (WHERE is_admin_added AND NOT is_customer_added AND NOT is_agent_added), 0)                                       AS drwise_coverage,
        COALESCE(SUM(total_premium) FILTER (WHERE (is_customer_added AND NOT is_admin_added AND NOT is_agent_added) OR (is_agent_added AND NOT is_customer_added AND NOT is_admin_added)), 0) AS non_drwise_premium,
        COALESCE(SUM(sum_insured)   FILTER (WHERE (is_customer_added AND NOT is_admin_added AND NOT is_agent_added) OR (is_agent_added AND NOT is_customer_added AND NOT is_admin_added)), 0) AS non_drwise_coverage
      FROM life_insurances
    SQL
    @drwise_count        = row['drwise_count'].to_i
    @non_drwise_count    = row['non_drwise_count'].to_i
    @drwise_premium      = row['drwise_premium'].to_f
    @drwise_coverage     = row['drwise_coverage'].to_f
    @non_drwise_premium  = row['non_drwise_premium'].to_f
    @non_drwise_coverage = row['non_drwise_coverage'].to_f

    if @current_tab == 'drwise'
      @total_policies_count  = @drwise_count
      @total_premium_amount  = @drwise_premium
      @total_coverage_amount = @drwise_coverage
      @covered_lives_count   = LifeInsurance.where(is_admin_added: true, is_customer_added: false, is_agent_added: false)
                                            .distinct.count(:customer_id)
    else
      @total_policies_count  = @non_drwise_count
      @total_premium_amount  = @non_drwise_premium
      @total_coverage_amount = @non_drwise_coverage
      @covered_lives_count   = LifeInsurance.where(
        '(is_customer_added = ? AND is_admin_added = ? AND is_agent_added = ?) OR (is_agent_added = ? AND is_customer_added = ? AND is_admin_added = ?)',
        true, false, false, true, false, false
      ).distinct.count(:customer_id)
    end
  end

  # R2 Upload Helper for main policy document
  def handle_main_policy_r2_upload(life_insurance)
    file = params[:life_insurance][:main_policy_document]
    return unless file.present?

    # Delete old R2 file if exists
    life_insurance.delete_main_policy_from_r2 if life_insurance.has_main_policy_r2_document?

    # Upload new file to R2
    result = life_insurance.upload_main_policy_to_r2(file)

    if result.is_a?(Hash) && !result[:error]
      flash[:notice] = (flash[:notice] || '') + " Main policy document uploaded successfully to R2."
    elsif result.is_a?(Hash) && result[:error]
      error_msg = result[:error]
      flash[:alert] = (flash[:alert] || '') + " Main policy document upload failed: #{error_msg}"
    elsif result == false
      flash[:alert] = (flash[:alert] || '') + " Main policy document upload failed: Unknown error"
    else
      flash[:notice] = (flash[:notice] || '') + " Main policy document uploaded successfully to R2."
    end
  end

  # R2 Upload Helper for additional documents (policy_documents and documents)
  def handle_additional_documents_r2_upload(life_insurance)
    uploaded_count = 0
    failed_count = 0

    # Handle uploaded_documents_attributes (from form) and convert to PolicyDocument records
    if params[:life_insurance][:uploaded_documents_attributes].present?
      params[:life_insurance][:uploaded_documents_attributes].each do |key, doc_attrs|
        next if doc_attrs[:file].blank? || doc_attrs[:_destroy] == "true"

        begin
          file = doc_attrs[:file]
          result = R2Service.upload(file, folder: "life_insurance/#{life_insurance.id}/uploaded_documents")

          if result[:error]
            Rails.logger.error "Failed to upload document: #{result[:error]}"
            failed_count += 1
          else
            # Map old document types to new PolicyDocument types
            mapped_doc_type = map_document_type_to_policy_document(doc_attrs[:document_type])

            # Create PolicyDocument record
            PolicyDocument.create!(
              policy_type: 'life',
              policy_id: life_insurance.id,
              document_type: mapped_doc_type,
              title: doc_attrs[:title] || result[:filename],
              description: doc_attrs[:description] || "Document uploaded on #{Date.current}",
              uploaded_by: doc_attrs[:uploaded_by] || current_user.email,
              r2_file_key: result[:key],
              r2_filename: result[:filename],
              r2_content_type: result[:content_type],
              r2_file_size: result[:size]
            )
            uploaded_count += 1
            Rails.logger.info "Uploaded document: #{result[:filename]} with title: #{doc_attrs[:title]}"
          end
        rescue => e
          Rails.logger.error "Error uploading document from uploaded_documents_attributes: #{e.message}"
          failed_count += 1
        end
      end
    end

    # Handle policy_documents array
    if params[:life_insurance][:policy_documents].present?
      params[:life_insurance][:policy_documents].each do |file|
        next if file.blank? || file == ""

        begin
          result = R2Service.upload(file, folder: "life_insurance/#{life_insurance.id}/policy_documents")

          if result[:error]
            Rails.logger.error "Failed to upload policy document: #{result[:error]}"
            failed_count += 1
          else
            # Create PolicyDocument record
            PolicyDocument.create!(
              policy_type: 'life',
              policy_id: life_insurance.id,
              document_type: 'Policy Document',
              title: result[:filename],
              description: "Policy document uploaded on #{Date.current}",
              uploaded_by: current_user.email,
              r2_file_key: result[:key],
              r2_filename: result[:filename],
              r2_content_type: result[:content_type],
              r2_file_size: result[:size]
            )
            uploaded_count += 1
            Rails.logger.info "Uploaded policy document: #{result[:filename]}"
          end
        rescue => e
          Rails.logger.error "Error uploading policy document: #{e.message}"
          failed_count += 1
        end
      end
    end

    # Handle documents array
    if params[:life_insurance][:documents].present?
      params[:life_insurance][:documents].each do |file|
        next if file.blank? || file == ""

        begin
          result = R2Service.upload(file, folder: "life_insurance/#{life_insurance.id}/documents")

          if result[:error]
            Rails.logger.error "Failed to upload document: #{result[:error]}"
            failed_count += 1
          else
            # Create PolicyDocument record
            PolicyDocument.create!(
              policy_type: 'life',
              policy_id: life_insurance.id,
              document_type: 'Additional Document',
              title: result[:filename],
              description: "Document uploaded on #{Date.current}",
              uploaded_by: current_user.email,
              r2_file_key: result[:key],
              r2_filename: result[:filename],
              r2_content_type: result[:content_type],
              r2_file_size: result[:size]
            )
            uploaded_count += 1
            Rails.logger.info "Uploaded document: #{result[:filename]}"
          end
        rescue => e
          Rails.logger.error "Error uploading document: #{e.message}"
          failed_count += 1
        end
      end
    end

    # Add feedback messages
    if uploaded_count > 0
      flash[:notice] = (flash[:notice] || '') + " #{uploaded_count} additional document(s) uploaded successfully to Cloudflare R2."
    end

    if failed_count > 0
      flash[:alert] = (flash[:alert] || '') + " #{failed_count} document(s) failed to upload."
    end
  end

  # Map old Document model types to PolicyDocument types
  def map_document_type_to_policy_document(old_type)
    case old_type&.to_s&.downcase
    when 'aadhar', 'pan_card', 'driving_license', 'passport', 'voter_id'
      'Identity Proof'
    when 'birth_certificate', 'marriage_certificate', 'income_certificate'
      'Additional Document'
    when 'salary_slip', 'bank_statement'
      'Additional Document'
    when 'gst_certificate'
      'Additional Document'
    when 'medical_report', 'medical'
      'Medical Report'
    when 'rc_book', 'rc'
      'RC Book'
    when 'policy_document', 'policy'
      'Policy Document'
    else
      'Other'
    end
  end
end