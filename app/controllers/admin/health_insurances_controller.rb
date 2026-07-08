class Admin::HealthInsurancesController < Admin::ApplicationController
  include ConfigurablePagination
  before_action :set_health_insurance, only: [:show, :edit, :update, :destroy, :renew, :create_renewal]
  before_action :load_form_data, only: [:new, :edit, :create, :update, :renew]
  skip_before_action :verify_authenticity_token, only: [:insurance_companies_by_agency]

  def index
    @health_insurances = HealthInsurance.includes(:customer, :sub_agent, :distributor, :agency_code, :broker, :renewal_policy)

    # Tab-based filtering for DrWise vs Non-DrWise policies
    @current_tab = params[:tab] || 'drwise'

    case @current_tab
    when 'drwise'
      # DrWise policies: Admin added policies (is_admin_added: true AND others false)
      @health_insurances = @health_insurances.where(
        is_admin_added: true,
        is_customer_added: false,
        is_agent_added: false
      )
    when 'non_drwise'
      # Non-DrWise policies: Customer or Agent added policies
      @health_insurances = @health_insurances.where(
        '(is_customer_added = ? AND is_admin_added = ? AND is_agent_added = ?) OR (is_agent_added = ? AND is_customer_added = ? AND is_admin_added = ?)',
        true, false, false, true, false, false
      )
    end

    # Search functionality (within current tab)
    if params[:search].present?
      @health_insurances = @health_insurances.search_health_policies(params[:search])
    end

    # Status filter
    if params[:status].present?
      case params[:status]
      when 'active'        then @health_insurances = @health_insurances.where('policy_end_date IS NULL OR policy_end_date >= ?', Date.current)
      when 'expiring_soon' then @health_insurances = @health_insurances.where(policy_end_date: Date.current..30.days.from_now)
      when 'expired'       then @health_insurances = @health_insurances.where('policy_end_date < ?', Date.current)
      end
    end

    # Advanced filters
    @health_insurances = @health_insurances.where(insurance_type: params[:insurance_type])   if params[:insurance_type].present?
    @health_insurances = @health_insurances.where(payment_mode: params[:payment_mode])        if params[:payment_mode].present?
    @health_insurances = @health_insurances.where(insurance_company_name: params[:company])   if params[:company].present?
    @health_insurances = @health_insurances.where(sub_agent_id: params[:sub_agent_id])        if params[:sub_agent_id].present?
    @health_insurances = @health_insurances.where(policy_type: params[:policy_type])          if params[:policy_type].present?
    @health_insurances = @health_insurances.where("policy_start_date >= ?", params[:from_date]) if params[:from_date].present?
    @health_insurances = @health_insurances.where("policy_start_date <= ?", params[:to_date])   if params[:to_date].present?

    # Filter dropdowns — 1 pluck replaces 2 distinct queries; sub_agents via id lookup
    hi_dropdown_data      = HealthInsurance.pluck(:insurance_company_name, :payment_mode, :sub_agent_id)
    @filter_companies     = hi_dropdown_data.map { |r| r[0] }.compact.uniq.reject(&:blank?).sort
    @filter_payment_modes = hi_dropdown_data.map { |r| r[1] }.compact.uniq.reject(&:blank?).sort
    hi_sub_agent_ids      = hi_dropdown_data.map { |r| r[2] }.compact.uniq
    @filter_sub_agents    = SubAgent.where(id: hi_sub_agent_ids).order(:first_name, :last_name)
    @filter_policy_types  = ['New', 'Renewal']

    # Calculate statistics for current tab (before pagination)
    calculate_tab_statistics

    @health_insurances = paginate_records(@health_insurances.order(policy_start_date: :desc))
  end

  def show
  end

  def new
    @health_insurance = HealthInsurance.new
    @health_insurance.health_insurance_members.build
    @health_insurance.health_insurance_nominees.build

    # Pre-fill customer data if coming from customer page
    if params[:customer_id].present?
      @selected_customer = Customer.find(params[:customer_id])
      @health_insurance.customer_id = @selected_customer.id

      # Auto-select customer's existing affiliate if they have one
      if @selected_customer.affiliate.present?
        @health_insurance.sub_agent_id = @selected_customer.affiliate.id
        @auto_select_affiliate = @selected_customer.affiliate.id
      else
        # Set 'Self' as default affiliate (no sub_agent)
        @auto_select_affiliate = 'self'
      end

      # Auto-populate family members as policy holder options
      @customer_family_members = @selected_customer.family_members.includes(:customer)
    end
  end

  def edit
  end

  def create
    processed_params = process_broker_params(health_insurance_params)
    # Extract main_policy_document from params to handle separately
    main_policy_document_file = processed_params.delete(:main_policy_document)
    # Extract additional documents so they go to R2, not Active Storage
    additional_document_files = Array(processed_params.delete(:documents)).reject(&:blank?)
    @health_insurance = HealthInsurance.new(processed_params)
    @health_insurance.main_policy_document = main_policy_document_file

    # Set admin tracking fields for policies created from admin panel
    @health_insurance.policy_added_by_admin = true
    @health_insurance.is_admin_added = true
    @health_insurance.is_customer_added = false
    @health_insurance.is_agent_added = false

    # Auto-set affiliate from customer if not already set
    if @health_insurance.sub_agent_id.blank? && @health_insurance.customer_id.present?
      customer = Customer.find(@health_insurance.customer_id)
      if customer.sub_agent_id.present?
        @health_insurance.sub_agent_id = customer.sub_agent_id
      elsif customer.lead_id.present?
        lead = Lead.find_by(lead_id: customer.lead_id)
        @health_insurance.sub_agent_id = lead.affiliate_id if lead&.affiliate_id.present?
      end
    end

    set_distributor_from_affiliate(@health_insurance)

    if @health_insurance.save
      # Handle R2 main policy document upload
      handle_main_policy_r2_upload(@health_insurance) if @health_insurance.main_policy_document.present?

      # Handle R2 document uploads after successful save
      handle_health_documents_r2_upload(@health_insurance, additional_document_files)

      redirect_to admin_health_insurance_path(@health_insurance), notice: 'Health insurance policy was successfully created.'
    else
      load_form_data
      render :new, status: :unprocessable_entity
    end
  end

  def update
    update_params = process_broker_params(health_insurance_params)
    # Extract main_policy_document from params to handle separately
    main_policy_document_file = update_params.delete(:main_policy_document)
    # Extract additional documents so they go to R2, not Active Storage
    additional_document_files = Array(update_params.delete(:documents)).reject(&:blank?)
    @health_insurance.assign_attributes(update_params)
    @health_insurance.main_policy_document = main_policy_document_file if main_policy_document_file.present?
    set_distributor_from_affiliate(@health_insurance)

    if @health_insurance.save
      # Handle R2 main policy document upload
      handle_main_policy_r2_upload(@health_insurance) if @health_insurance.main_policy_document.present?

      # Handle R2 document uploads after successful save
      handle_health_documents_r2_upload(@health_insurance, additional_document_files)

      redirect_to admin_health_insurance_path(@health_insurance), notice: 'Health insurance policy was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    policy_number = @health_insurance.policy_number
    customer_name = @health_insurance.customer&.display_name

    begin
      ActiveRecord::Base.transaction do
        # 1. Delete commission payouts for this health insurance
        CommissionPayout.where(policy_type: 'health', policy_id: @health_insurance.id).destroy_all

        # 2. Delete main payouts for this health insurance
        Payout.where(policy_type: 'health', policy_id: @health_insurance.id).destroy_all

        # 3. Delete lead record if it was created for this policy
        if @health_insurance.lead_id.present?
          lead = Lead.find_by(lead_id: @health_insurance.lead_id)
          if lead && lead.policy_created_id == @health_insurance.id
            lead.destroy
          end
        end

        # 4. Delete policy documents from R2 and database
        @health_insurance.policy_documents_records.each do |doc|
          # Delete from R2 if file key exists
          if doc.r2_file_key.present?
            R2Service.delete_file(doc.r2_file_key) rescue Rails.logger.warn("Failed to delete R2 file: #{doc.r2_file_key}")
          end
        end

        # 5. Delete uploaded documents from R2
        @health_insurance.uploaded_documents.each do |doc|
          if doc.respond_to?(:file) && doc.file.attached?
            doc.file.purge rescue Rails.logger.warn("Failed to purge uploaded document")
          end
        end

        # 6. Delete attached documents
        @health_insurance.documents.purge rescue Rails.logger.warn("Failed to purge attached documents")
        @health_insurance.policy_documents.purge rescue Rails.logger.warn("Failed to purge policy documents")

        # 7. Delete the health insurance record (this will cascade to dependent associations)
        @health_insurance.destroy!
      end

      redirect_to admin_health_insurances_path,
                  notice: "Health insurance policy #{policy_number} for #{customer_name} and all associated data were successfully deleted."

    rescue => e
      Rails.logger.error "Failed to delete health insurance #{@health_insurance.id}: #{e.message}"
      redirect_to admin_health_insurances_path,
                  alert: "Failed to delete health insurance policy. Error: #{e.message}"
    end
  end

  # AJAX endpoint for getting policy holder options based on customer
  def policy_holder_options
    customer = Customer.find(params[:customer_id]) if params[:customer_id].present?

    options = [{ label: 'Self', value: 'Self' }]

    if customer&.family_members&.any?
      customer.family_members.each do |member|
        options << {
          label: "#{member.name} (#{member.relationship.humanize})",
          value: member.name
        }
      end
    end

    render json: { options: options }
  end

  # API endpoints for dynamic dropdowns
  def agency_codes_for_broker_type
    broker_type = params[:broker_type]

    case broker_type
    when 'direct'
      # FLOW 1: Direct mode - Fetch agents for health insurance
      # API response format: { agent1: company_name_1, agent2: company_name_2 }
      agency_codes = AgencyCode.where(insurance_type: 'Health Insurance')
                               .select(:id, :agent_name, :code, :company_name)
                               .order(:agent_name)

      # Transform to required format for dropdown
      agents_data = agency_codes.map { |ac|
        {
          id: ac.id,
          text: "#{ac.agent_name} - #{ac.code}",  # Show agent name with code in dropdown
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
      # FLOW 2: Broking mode - Fetch all active broker codes for health insurance
      # One entry per broker code so brokers with multiple codes all appear
      broker_codes = BrokerCode.includes(:broker).active.joins(:broker).order('brokers.name, broker_codes.broker_code')

      brokers_data = broker_codes.map { |bc|
        {
          id: bc.id,
          text: "#{bc.broker.name} - #{bc.broker_code}",
          broker_name: bc.broker.name,
          code: bc.broker_code
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

  # API endpoint for getting company name by agent selection (Direct mode only)
  def company_name_by_agent
    agency_code_id = params[:agency_code_id]

    if agency_code_id.present?
      agency_code = AgencyCode.find_by(id: agency_code_id)

      if agency_code
        # Get all companies for this agent name in health insurance
        agent_name = agency_code.agent_name
        company_names = AgencyCode.where(
          agent_name: agent_name,
          insurance_type: 'Health Insurance'
        ).pluck(:company_name).compact.uniq

        if company_names.length == 1
          # Single company - return as before for compatibility
          render json: {
            success: true,
            data: {
              company_name: company_names.first,
              agent_name: agent_name
            }
          }
        else
          # Multiple companies - return all options
          render json: {
            success: true,
            data: {
              company_names: company_names,
              agent_name: agent_name,
              multiple_companies: true
            }
          }
        end
      else
        render json: { success: false, message: 'Agency code not found' }
      end
    else
      render json: { success: false, message: 'Agency code ID is required' }
    end
  end

  # API endpoint for insurance companies (independent for Broking mode)
  def insurance_companies_for_type
    # FLOW 2: Broking mode - Fetch all health insurance companies
    # API response format: { company1, company2 }

    # For health insurance, use the health insurance companies
    companies = InsuranceCompany.where(insurance_type: "health").order('LOWER(name) ASC').pluck(:name)

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
                     AgencyCode.where(broker_id: broker_id, insurance_type: 'Health Insurance').order(:code)
                   else
                     AgencyCode.none
                   end
    render json: {
      agency_codes: agency_codes.map { |a| { id: a.id, name: "#{a.company_name} - #{a.code}" } }
    }
  end

  # API endpoint for getting all agency codes (for Direct selection)
  def all_agency_codes
    agency_codes = AgencyCode.where(insurance_type: 'Health Insurance').order(:code)
    render json: {
      agency_codes: agency_codes.map { |a| { id: a.id, name: "#{a.company_name} - #{a.code}" } }
    }
  end

  # API endpoint for getting all brokers (for Broking selection)
  def all_brokers
    brokers = Broker.active.order(:name)
    render json: {
      brokers: brokers.map { |b| { id: b.id, name: b.name } }
    }
  end

  # API endpoint for getting insurance companies by agency code
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
      # For direct mode: Get companies mapped to the selected agency
      company_names = AgencyCode.where(
        insurance_type: 'Health Insurance',
        id: agency_code_id
      ).pluck(:company_name).compact.uniq

      if company_names.any?
        # Find insurance companies with fuzzy matching
        all_insurance_companies = InsuranceCompany.where(insurance_type: 'health')
        matching_companies = []

        company_names.each do |agency_company_name|
          # Try exact match first
          exact_match = all_insurance_companies.find_by(name: agency_company_name)
          if exact_match
            matching_companies << exact_match
          else
            # Try fuzzy matching - look for companies that contain similar words
            agency_words = agency_company_name.downcase.split.reject { |w| w.length < 4 }
            fuzzy_matches = all_insurance_companies.select do |company|
              company_words = company.name.downcase.split.reject { |w| w.length < 4 }
              # Check if main company words match (require at least 2 significant word matches)
              common_words = agency_words & company_words
              common_words.length >= 2 ||
              (agency_words.include?('star') && company_words.include?('star')) ||
              (agency_words.include?('tata') && company_words.include?('tata'))
            end
            matching_companies.concat(fuzzy_matches)
          end
        end

        companies_data = matching_companies.uniq.map do |company|
          {
            id: company.id,
            name: company.name
          }
        end
      end

    when 'broking'
      # For broking mode: Show all health insurance companies
      insurance_companies = InsuranceCompany.where(insurance_type: 'health')

      companies_data = insurance_companies.map do |company|
        {
          id: company.id,
          name: company.name
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

  def create_renewal
    # Check if policy expires within 60 days
    if @health_insurance.policy_end_date.blank? || @health_insurance.policy_end_date > 60.days.from_now
      redirect_to admin_health_insurances_path, alert: "This policy is not eligible for renewal yet."
      return
    end

    # Create new policy with renewal data
    processed_params = process_broker_params(health_insurance_params)

    # Strip nominee IDs — the renew form copies nominees from the original policy,
    # so their IDs belong to a different HealthInsurance. Passing them to a new
    # record causes Rails to raise RecordNotFound when looking up the existing nominee.
    if processed_params[:health_insurance_nominees_attributes].present?
      processed_params[:health_insurance_nominees_attributes].each_value { |attrs| attrs.delete('id') }
    end

    @renewed_policy = HealthInsurance.new(processed_params)
    @renewed_policy.policy_type = 'Renewal'
    @renewed_policy.original_policy_id = @health_insurance.id

    # Preserve company name from original policy if the select didn't submit one
    @renewed_policy.insurance_company_name ||= @health_insurance.insurance_company_name

    # Set admin added flags for renewal (same as original)
    @renewed_policy.is_admin_added = @health_insurance.is_admin_added
    @renewed_policy.is_customer_added = @health_insurance.is_customer_added
    @renewed_policy.is_agent_added = @health_insurance.is_agent_added

    # Ensure distributor is set from affiliate before saving
    set_distributor_from_affiliate(@renewed_policy)

    if @renewed_policy.save
      # Mark original policy as renewed
      @health_insurance.update_column(:is_renewed, true)

      # Handle R2 document uploads
      handle_main_policy_r2_upload(@renewed_policy) if params[:health_insurance][:main_policy_document].present?
      handle_health_documents_r2_upload(@renewed_policy)

      redirect_to admin_health_insurance_path(@renewed_policy),
                  notice: 'Health insurance renewal policy was successfully created.'
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
      @health_insurance = @renewed_policy
      render :renew, status: :unprocessable_entity
    end
  end

  # API endpoint for loading customer nominees
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

  # GET /admin/insurance/health/download
  def download
    format_type = params[:format_type]
    scope = build_health_filtered_scope.order(created_at: :desc)

    case format_type
    when 'csv'
      send_data generate_health_csv(scope),
                filename: "health_insurance_#{Date.current}.csv", type: 'text/csv'
    when 'excel'
      send_data generate_health_excel(scope),
                filename: "health_insurance_#{Date.current}.xlsx",
                type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    else
      redirect_to admin_health_insurances_path, alert: 'Invalid download format.'
    end
  end

  private

  def build_health_filtered_scope
    scope = HealthInsurance.includes(:customer, :sub_agent)
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
    scope = scope.search_health_policies(params[:search]) if params[:search].present?
    if params[:status].present?
      case params[:status]
      when 'active'        then scope = scope.where('policy_end_date IS NULL OR policy_end_date >= ?', Date.current)
      when 'expiring_soon' then scope = scope.where(policy_end_date: Date.current..30.days.from_now)
      when 'expired'       then scope = scope.where('policy_end_date < ?', Date.current)
      end
    end
    scope = scope.where(insurance_type: params[:insurance_type])      if params[:insurance_type].present?
    scope = scope.where(payment_mode: params[:payment_mode])          if params[:payment_mode].present?
    scope = scope.where(insurance_company_name: params[:company])     if params[:company].present?
    scope = scope.where(sub_agent_id: params[:sub_agent_id])          if params[:sub_agent_id].present?
    scope = scope.where(policy_type: params[:policy_type])            if params[:policy_type].present?
    scope = scope.where("policy_start_date >= ?", params[:from_date]) if params[:from_date].present?
    scope = scope.where("policy_start_date <= ?", params[:to_date])   if params[:to_date].present?
    scope
  end

  def generate_health_csv(records)
    require 'csv'
    CSV.generate(headers: true) do |csv|
      csv << %w[ID PolicyNumber PolicyType InsuranceType CustomerName CustomerEmail
                InsuranceCompany SumInsured TotalPremium NetPremium PaymentMode
                PolicyStartDate PolicyEndDate PolicyHolder PlanName Status Source
                Affiliate BookingDate CreatedAt]
      records.find_each do |p|
        source = if p.is_admin_added? then 'Admin' elsif p.is_agent_added? then 'Agent' elsif p.is_customer_added? then 'Customer' else 'Unknown' end
        csv << [p.id, p.policy_number, p.policy_type, p.insurance_type,
                p.customer&.display_name, p.customer&.email, p.insurance_company_name,
                p.sum_insured, p.total_premium, p.net_premium, p.payment_mode,
                p.policy_start_date, p.policy_end_date, p.policy_holder, p.plan_name,
                p.status, source, p.sub_agent&.display_name,
                p.policy_booking_date, p.created_at.strftime('%Y-%m-%d %H:%M:%S')]
      end
    end
  end

  def generate_health_excel(records)
    require 'caxlsx'
    package = Axlsx::Package.new
    wb = package.workbook
    hdr = wb.styles.add_style(bg_color: '1B5E20', fg_color: 'FFFFFF', b: true, alignment: { horizontal: :center })
    row = wb.styles.add_style(alignment: { horizontal: :left })
    wb.add_worksheet(name: 'Health Insurance') do |sheet|
      sheet.add_row %w[ID PolicyNumber PolicyType InsuranceType CustomerName CustomerEmail
                       InsuranceCompany SumInsured TotalPremium NetPremium PaymentMode
                       PolicyStartDate PolicyEndDate PolicyHolder PlanName Status Source
                       Affiliate BookingDate CreatedAt], style: hdr
      records.find_each do |p|
        source = if p.is_admin_added? then 'Admin' elsif p.is_agent_added? then 'Agent' elsif p.is_customer_added? then 'Customer' else 'Unknown' end
        sheet.add_row [p.id, p.policy_number, p.policy_type, p.insurance_type,
                       p.customer&.display_name, p.customer&.email, p.insurance_company_name,
                       p.sum_insured.to_f, p.total_premium.to_f, p.net_premium.to_f, p.payment_mode,
                       p.policy_start_date&.to_s, p.policy_end_date&.to_s, p.policy_holder, p.plan_name,
                       p.status, source, p.sub_agent&.display_name,
                       p.policy_booking_date&.to_s, p.created_at.strftime('%Y-%m-%d %H:%M:%S')], style: row
      end
    end
    package.to_stream.read
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
      FROM health_insurances
    SQL
    @drwise_count        = row['drwise_count'].to_i
    @non_drwise_count    = row['non_drwise_count'].to_i
    @drwise_premium      = row['drwise_premium'].to_f
    @drwise_coverage     = row['drwise_coverage'].to_f
    @non_drwise_premium  = row['non_drwise_premium'].to_f
    @non_drwise_coverage = row['non_drwise_coverage'].to_f

    base = @health_insurances.unscope(:includes, :order, :select)
    @active_policies = base.where('policy_end_date IS NULL OR policy_end_date >= CURRENT_DATE').count
    @expiring_soon   = base.where('policy_end_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL \'30 days\')').count

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

  def process_broker_params(params)
    # Handle agency_code_id when it contains broker_X format (X is BrokerCode.id)
    if params[:agency_code_id].present? && params[:agency_code_id].start_with?('broker_')
      broker_code_id = params[:agency_code_id].gsub('broker_', '').to_i
      if broker_code_id > 0
        broker_code = BrokerCode.find_by(id: broker_code_id)
        params[:broker_id] = broker_code.broker_id if broker_code
        params[:agency_code_id] = nil
      end
    end
    params
  end

  def set_health_insurance
    @health_insurance = HealthInsurance.includes(:agency_code, :health_insurance_nominees).find(params[:id])
  end

  def load_form_data
    @customers = Customer.active.order(:first_name, :last_name, :company_name)
    @sub_agents = SubAgent.active.order(:first_name, :last_name)
    @distributors = Distributor.active.order(:first_name, :last_name)
    @investors = Investor.active.order(:first_name, :last_name)
    @agency_codes = AgencyCode.where(insurance_type: 'Health Insurance')
    @brokers = Broker.active.order(:name)
    # Load only health insurance companies - sorted alphabetically
    @insurance_companies = InsuranceCompany.where(insurance_type: 'health').order('LOWER(name) ASC').pluck(:name)

    # Ensure the current policy's company is always available (in case it's not health-typed in the DB)
    if @health_insurance&.insurance_company_name.present?
      unless @insurance_companies.include?(@health_insurance.insurance_company_name)
        @insurance_companies = (@insurance_companies + [@health_insurance.insurance_company_name]).sort
      end
    end
  end

  def health_insurance_params
    params.require(:health_insurance).permit(
      :customer_id, :sub_agent_id, :distributor_id, :investor_id, :agency_code_id, :broker_id, :broker_code_type,
      :policy_holder, :insurance_company_name, :policy_type, :insurance_type,
      :plan_name, :policy_number, :policy_booking_date, :policy_start_date,
      :policy_end_date, :policy_term, :payment_mode, :claim_process,
      :sum_insured, :sum_insured_text, :net_premium, :gst_percentage, :total_premium,
      :main_agent_commission_percentage, :commission_amount, :tds_percentage,
      :tds_amount, :after_tds_value, :reference_by_name,
      :installment_autopay_start_date, :installment_autopay_end_date,
      # New fields for edit form
      :premium_frequency, :status, :start_date, :end_date, :additional_details,
      :nominee_name, :nominee_relation, :nominee_dob,
      # Commission details for all stakeholders
      :sub_agent_commission_percentage, :sub_agent_commission_amount, :sub_agent_tds_percentage, :sub_agent_tds_amount, :sub_agent_after_tds_value,
      :ambassador_commission_percentage, :ambassador_commission_amount, :ambassador_tds_percentage, :ambassador_tds_amount, :ambassador_after_tds_value,
      :investor_commission_percentage, :investor_commission_amount, :investor_tds_percentage, :investor_tds_amount, :investor_after_tds_value,
      # Company expenses and profit fields
      :company_expenses_percentage, :company_expenses_amount, :total_distribution_percentage, :profit_percentage, :profit_amount,
      # Main policy document
      :main_policy_document,
      health_insurance_members_attributes: [:id, :member_name, :age, :relationship, :sum_insured, :_destroy],
      health_insurance_nominees_attributes: [:id, :nominee_name, :relationship, :age, :share_percentage, :_destroy],
      # R2 Documents
      health_insurance_documents_attributes: [:id, :title, :description, :document_type, :r2_file_key, :r2_filename, :r2_content_type, :r2_file_size, :_destroy],
      # Legacy support
      documents: [],
      policy_documents: [],
      uploaded_documents_attributes: [:id, :title, :description, :document_type, :file, :uploaded_by, :_destroy]
    )
  end

  def renew
    # Check if policy expires within 60 days
    if @health_insurance.policy_end_date.blank? || @health_insurance.policy_end_date > 60.days.from_now
      redirect_to admin_health_insurances_path, alert: "This policy is not eligible for renewal yet."
      return
    end

    # Create a new health insurance object with ALL data from the original policy
    @renewed_policy = @health_insurance.dup

    # Keep all the original policy data but update specific fields for renewal
    @renewed_policy.id = nil
    @renewed_policy.created_at = nil
    @renewed_policy.updated_at = nil

    # Set policy type to Renewal
    @renewed_policy.policy_type = 'Renewal'

    # Store original policy number for display
    @original_policy_number = @health_insurance.policy_number

    # Clear policy number (user needs to enter new one)
    @renewed_policy.policy_number = nil

    # Set booking date to current date
    @renewed_policy.policy_booking_date = Date.current

    # Calculate new policy dates based on payment mode
    if @health_insurance.policy_end_date.present?
      # Start date is day after current policy ends
      @renewed_policy.policy_start_date = @health_insurance.policy_end_date + 1.day

      # Calculate end date based on payment mode
      case @health_insurance.payment_mode
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

    # Also update the start_date and end_date fields if they exist
    @renewed_policy.start_date = @renewed_policy.policy_start_date
    @renewed_policy.end_date = @renewed_policy.policy_end_date

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
    @renewed_policy.original_policy_id = @health_insurance.id

    # Clear notification dates
    @renewed_policy.notification_dates = nil

    # Clear renewal flag
    @renewed_policy.is_renewed = false

    # Load form data for the renewal form
    load_form_data

    # Set up family members for Policy Holder dropdown
    @customer_family_members = []
    if @health_insurance.customer.present?
      @customer_family_members = @health_insurance.customer.family_members.includes(:customer).to_a
    end

    # Store original members and nominees before reassignment
    original_members  = @health_insurance.health_insurance_members.to_a
    original_nominees = @health_insurance.health_insurance_nominees.to_a

    # Auto-set affiliate based on original policy or customer
    if @renewed_policy.sub_agent_id.present?
      @auto_select_affiliate = @renewed_policy.sub_agent_id
    elsif @renewed_policy.customer.present? && @renewed_policy.customer.sub_agent_id.present?
      @renewed_policy.sub_agent_id = @renewed_policy.customer.sub_agent_id
      @auto_select_affiliate = @renewed_policy.customer.sub_agent_id
    else
      @auto_select_affiliate = 'self'
    end

    # Assign to instance variable for form FIRST
    @health_insurance = @renewed_policy

    # Reset any associations that may have been inherited from the dup
    @health_insurance.health_insurance_members.reset
    @health_insurance.health_insurance_nominees.reset

    # Copy members from original policy
    if original_members.any?
      original_members.each do |original_member|
        @health_insurance.health_insurance_members.build(
          member_name: original_member.member_name,
          age: original_member.age,
          relationship: original_member.relationship,
          sum_insured: original_member.sum_insured
        )
      end
    else
      @health_insurance.health_insurance_members.build
    end

    # Copy nominees from original policy — all 4 fields
    if original_nominees.any?
      original_nominees.each do |nom|
        @health_insurance.health_insurance_nominees.build(
          nominee_name: nom.nominee_name,
          relationship: nom.relationship,
          age: nom.age,
          share_percentage: nom.share_percentage
        )
      end
    else
      @health_insurance.health_insurance_nominees.build
    end
  end

  # API endpoint for loading customer nominees

  private

  def set_distributor_from_affiliate(insurance_record)
    # If affiliate is selected but distributor is not set, auto-assign distributor
    if insurance_record.sub_agent_id.present? && insurance_record.distributor_id.blank?
      sub_agent = SubAgent.find(insurance_record.sub_agent_id)

      # Use direct distributor relationship first, then fall back to assignment
      distributor_id = sub_agent.distributor_id || sub_agent.assigned_distributor&.id

      insurance_record.distributor_id = distributor_id if distributor_id.present?
    end
  rescue StandardError => e
    # Log error but don't fail the form submission
    Rails.logger.error "Failed to set distributor from affiliate: #{e.message}"
  end

  # Handle Health Insurance documents R2 upload
  def handle_health_documents_r2_upload(health_insurance, additional_files = [])
    uploaded_count = 0
    failed_count = 0

    Rails.logger.info "Starting R2 document upload for health insurance #{health_insurance.id}"

    # Handle health_insurance_documents_attributes (from "Add Document" button)
    if params[:health_insurance][:health_insurance_documents_attributes].present?
      params[:health_insurance][:health_insurance_documents_attributes].each do |key, doc_attrs|
        next if doc_attrs[:_destroy] == "true"

        file = request.params.dig('health_insurance', 'health_insurance_documents_attributes', key, 'file')
        next if file.blank?

        begin
          result = R2Service.upload(file, folder: "health_insurance/#{health_insurance.id}/documents")

          if result && result[:key] && !result[:error]
            health_insurance.health_insurance_documents.create!(
              document_type: doc_attrs[:document_type].presence || 'other',
              title: doc_attrs[:title].presence || file.original_filename,
              description: doc_attrs[:description],
              r2_file_key: result[:key],
              r2_filename: result[:filename],
              r2_content_type: result[:content_type],
              r2_file_size: result[:size]
            )
            uploaded_count += 1
          else
            Rails.logger.error "R2 upload failed for document: #{doc_attrs[:title]} - #{result[:error]}"
            failed_count += 1
          end
        rescue => e
          Rails.logger.error "Error uploading health document: #{e.message}"
          failed_count += 1
        end
      end
    end

    # Handle additional documents (from the "Additional Documents" multi-file field)
    Array(additional_files).each do |file|
      next if file.blank?

      begin
        result = R2Service.upload(file, folder: "health_insurance/#{health_insurance.id}/documents")

        if result && result[:key] && !result[:error]
          health_insurance.health_insurance_documents.create!(
            document_type: 'other',
            title: file.original_filename || 'Additional Document',
            r2_file_key: result[:key],
            r2_filename: result[:filename],
            r2_content_type: result[:content_type],
            r2_file_size: result[:size]
          )
          uploaded_count += 1
        else
          Rails.logger.error "R2 upload failed for additional document: #{result[:error]}"
          failed_count += 1
        end
      rescue => e
        Rails.logger.error "Error uploading additional document: #{e.message}"
        failed_count += 1
      end
    end

    Rails.logger.info "Health Insurance documents upload completed: #{uploaded_count} uploaded, #{failed_count} failed" if uploaded_count > 0

    { uploaded: uploaded_count, failed: failed_count }
  end

  # R2 Upload Helper for main policy document
  def handle_main_policy_r2_upload(health_insurance)
    file = health_insurance.main_policy_document
    return unless file.present?

    begin
      result = health_insurance.upload_main_policy_to_r2(file)

      if result && result[:key] && !result[:error]
        flash[:notice] = (flash[:notice] || '') + " Main policy document uploaded successfully to R2."
      else
        error_msg = result[:error] || "Unknown error"
        flash[:alert] = (flash[:alert] || '') + " Main policy document upload failed: #{error_msg}"
      end
    rescue => e
      Rails.logger.error "Error uploading main policy document: #{e.message}"
      flash[:alert] = (flash[:alert] || '') + " Main policy document upload failed: #{e.message}"
    end
  end

  # Handle document uploads to Cloudflare R2 (Legacy method - keeping for compatibility)
  def handle_document_uploads(health_insurance)
    uploaded_count = 0
    failed_count = 0

    begin
      # Handle health_insurance_documents_attributes (Document Management System)
      if params[:health_insurance] && params[:health_insurance][:health_insurance_documents_attributes].present?
        params[:health_insurance][:health_insurance_documents_attributes].each do |index, document_data|
          next if document_data.blank? || document_data[:file].blank?

          file = document_data[:file]
          title = document_data[:title].presence || file.original_filename
          document_type = document_data[:document_type].presence || 'policy_document'
          description = document_data[:description].presence || ''

          # Upload to R2
          result = R2Service.upload(file, folder: "health_insurance/#{health_insurance.id}/health_documents")

          if result[:error]
            Rails.logger.error "Failed to upload health insurance document: #{result[:error]}"
            failed_count += 1
            flash[:alert] = (flash[:alert] || '') + " Health document upload failed: #{result[:error]}. "
          else
            # Create HealthInsuranceDocument record
            HealthInsuranceDocument.create!(
              health_insurance: health_insurance,
              document_type: document_type,
              title: title,
              description: description,
              r2_file_key: result[:key],
              r2_filename: result[:filename],
              r2_content_type: file.content_type,
              r2_file_size: file.size
            )
            uploaded_count += 1
            Rails.logger.info "HealthInsuranceDocument created for health insurance #{health_insurance.id}: #{title}"
          end
        end
      end
      # Handle policy_documents from the Add Document form
      if params[:policy_documents].present?
        params[:policy_documents].each do |index, document_data|
          next if document_data.blank? || document_data[:file].blank?

          file = document_data[:file]
          title = document_data[:title].presence || file.original_filename
          document_type = document_data[:document_type].presence || 'Policy Document'
          description = document_data[:description].presence || ''

          # Upload to R2
          result = R2Service.upload(file, folder: "health_insurance/#{health_insurance.id}/policy_documents")

          if result[:error]
            Rails.logger.error "Failed to upload policy document: #{result[:error]}"
            failed_count += 1
            flash[:alert] = (flash[:alert] || '') + " Document upload failed: #{result[:error]}. "
          else
            # Create PolicyDocument record
            PolicyDocument.create!(
              policy_type: 'health',
              policy_id: health_insurance.id,
              document_type: document_type,
              title: title,
              description: description,
              r2_file_key: result[:key],
              r2_filename: result[:filename],
              r2_content_type: file.content_type,
              r2_file_size: file.size,
              uploaded_by: current_user&.email || 'admin'
            )
            uploaded_count += 1
            Rails.logger.info "PolicyDocument created for health insurance #{health_insurance.id}: #{title}"
          end
        end
      end

      # Handle legacy policy_documents array (from file upload fields)
      if params[:health_insurance] && params[:health_insurance][:policy_documents].present?
        params[:health_insurance][:policy_documents].each do |file|
          next if file.blank? || file == ""

          # Upload to R2
          result = R2Service.upload(file, folder: "health_insurance/#{health_insurance.id}/documents")

          if result[:error]
            Rails.logger.error "Failed to upload document: #{result[:error]}"
            failed_count += 1
            flash[:alert] = (flash[:alert] || '') + " Document upload failed: #{result[:error]}. "
          else
            # Create PolicyDocument record
            PolicyDocument.create!(
              policy_type: 'health',
              policy_id: health_insurance.id,
              document_type: 'Policy Document',
              title: file.original_filename,
              description: 'Uploaded policy document',
              r2_file_key: result[:key],
              r2_filename: result[:filename],
              r2_content_type: file.content_type,
              r2_file_size: file.size,
              uploaded_by: current_user&.email || 'admin'
            )
            uploaded_count += 1
            Rails.logger.info "PolicyDocument created for health insurance #{health_insurance.id}: #{file.original_filename}"
          end
        end
      end

      # Handle documents array (additional documents)
      if params[:health_insurance] && params[:health_insurance][:documents].present?
        params[:health_insurance][:documents].each do |file|
          next if file.blank? || file == ""

          # Upload to R2
          result = R2Service.upload(file, folder: "health_insurance/#{health_insurance.id}/additional_documents")

          if result[:error]
            Rails.logger.error "Failed to upload additional document: #{result[:error]}"
            failed_count += 1
            flash[:alert] = (flash[:alert] || '') + " Additional document upload failed: #{result[:error]}. "
          else
            # Create PolicyDocument record
            PolicyDocument.create!(
              policy_type: 'health',
              policy_id: health_insurance.id,
              document_type: 'Additional Document',
              title: file.original_filename,
              description: 'Additional uploaded document',
              r2_file_key: result[:key],
              r2_filename: result[:filename],
              r2_content_type: file.content_type,
              r2_file_size: file.size,
              uploaded_by: current_user&.email || 'admin'
            )
            uploaded_count += 1
            Rails.logger.info "Additional document created for health insurance #{health_insurance.id}: #{file.original_filename}"
          end
        end
      end

      # Update flash messages
      if uploaded_count > 0
        flash[:notice] = (flash[:notice] || '') + " #{uploaded_count} document(s) uploaded successfully to Cloudflare R2. "
      end

      if failed_count > 0
        flash[:alert] = (flash[:alert] || '') + " #{failed_count} document(s) failed to upload. "
      end

    rescue => e
      Rails.logger.error "Document upload error: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      flash[:alert] = (flash[:alert] || '') + " Document upload failed: #{e.message}. "
    end
  end
end