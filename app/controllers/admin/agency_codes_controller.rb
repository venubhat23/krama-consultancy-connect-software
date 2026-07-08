class Admin::AgencyCodesController < Admin::ApplicationController
  include InsuranceCompanyMethods

  before_action :set_agency_code, only: [:show, :edit, :update, :destroy]

  # GET /admin/agency_codes
  def index
    @agency_codes = AgencyCode.all

    # Apply search filter
    if params[:search].present?
      @agency_codes = @agency_codes.search(params[:search])
    end

    # Apply company filter
    if params[:company].present?
      @agency_codes = @agency_codes.by_company(params[:company])
    end

    # Apply insurance type filter
    if params[:insurance_type].present?
      @agency_codes = @agency_codes.by_insurance_type(params[:insurance_type])
    end


    respond_to do |format|
      format.html do
        # Get total count before pagination for display purposes
        @total_filtered_count = @agency_codes.count

        # Apply pagination (10 records per page)
        @agency_codes = @agency_codes.order(created_at: :desc).page(params[:page]).per(10)

        # For filters - get all companies sorted alphabetically
        @insurance_companies = get_all_companies_sorted

        # Statistics (use unfiltered counts for stats cards)
        @total_codes = AgencyCode.count
        @health_codes = AgencyCode.where(insurance_type: 'Health Insurance').count
        @motor_codes = AgencyCode.where(insurance_type: 'Motor and Other Insurance').count
        @life_codes = AgencyCode.where(insurance_type: 'Life Insurance').count
      end

      format.json do
        # Handle type parameter for AJAX filtering
        if params[:type].present?
          @agency_codes = case params[:type]
          when 'agent'
            @agency_codes.where(code_type: 'Agent')
          when 'broker'
            @agency_codes.where(code_type: 'Broker')
          else
            @agency_codes
          end
        end

        # For JSON requests, return all matching records without pagination
        @agency_codes = @agency_codes.order(:agent_name, :code)
        render json: @agency_codes.map do |agency_code|
          {
            id: agency_code.id,
            agent_name: agency_code.agent_name,
            code: agency_code.code,
            company_name: agency_code.company_name,
            insurance_type: agency_code.insurance_type,
            broker_id: agency_code.broker_id
          }
        end
      end
    end
  end

  # GET /admin/agency_codes/1
  def show
  end

  # GET /admin/agency_codes/new
  def new
    @agency_code = AgencyCode.new
    @insurance_types = ['Health Insurance', 'Life Insurance', 'Motor and Other Insurance']
  end

  # GET /admin/agency_codes/1/edit
  def edit
    @insurance_types = ['Health Insurance', 'Life Insurance', 'Motor and Other Insurance']
    @insurance_companies = get_companies_for_insurance_type(@agency_code.insurance_type)

    # Ensure the current company is included in the list even if it's not in the standard list
    if @agency_code.company_name.present? && !@insurance_companies.include?(@agency_code.company_name)
      @insurance_companies << @agency_code.company_name
      @insurance_companies.sort!
    end
  end

  # POST /admin/agency_codes
  def create
    @agency_code = AgencyCode.new(agency_code_params)

    if @agency_code.save
      redirect_to admin_agency_codes_path, notice: 'Agency code was successfully created.'
    else
      @insurance_types = ['Health Insurance', 'Life Insurance', 'Motor and Other Insurance']
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /admin/agency_codes/1
  def update
    if @agency_code.update(agency_code_params)
      redirect_to admin_agency_codes_path, notice: 'Agency code was successfully updated.'
    else
      @insurance_types = ['Health Insurance', 'Life Insurance', 'Motor and Other Insurance']
      @insurance_companies = get_companies_for_insurance_type(@agency_code.insurance_type)

      # Ensure the current company is included in the list even if it's not in the standard list
      if @agency_code.company_name.present? && !@insurance_companies.include?(@agency_code.company_name)
        @insurance_companies << @agency_code.company_name
        @insurance_companies.sort!
      end

      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/agency_codes/1
  def destroy
    @agency_code.destroy
    redirect_to admin_agency_codes_path, notice: 'Agency code was successfully deleted.'
  end

  # GET /admin/agency_codes/search - For AJAX search
  def search
    @agency_codes = AgencyCode.all

    if params[:search].present?
      @agency_codes = @agency_codes.search(params[:search])
    end

    if params[:company].present?
      @agency_codes = @agency_codes.by_company(params[:company])
    end

    if params[:insurance_type].present?
      @agency_codes = @agency_codes.by_insurance_type(params[:insurance_type])
    end


    # Get total count before pagination for display purposes
    @total_filtered_count = @agency_codes.count

    # Apply pagination (10 records per page)
    @agency_codes = @agency_codes.order(created_at: :desc).page(params[:page]).per(10)

    render partial: 'agency_codes_table', locals: { agency_codes: @agency_codes, total_filtered_count: @total_filtered_count }
  end

  # GET /admin/agency_codes/brokers_for_direct - API endpoint for fetching all brokers when Direct is selected
  def brokers_for_direct
    # Get all active brokers for direct business
    @brokers = Broker.active.order(:name)

    respond_to do |format|
      format.json do
        render json: {
          success: true,
          brokers: @brokers.map { |broker| { id: broker.id, name: broker.name } }
        }
      end
    end
  rescue => e
    respond_to do |format|
      format.json do
        render json: {
          success: false,
          message: "Error fetching brokers: #{e.message}"
        }, status: :internal_server_error
      end
    end
  end

  # GET /admin/agency_codes/all_agents - API endpoint for fetching all agent names when Direct is selected
  def all_agents
    
    insurance_type = params[:insurance_type] || 'Life Insurance'
    if (insurance_type == "Life") || (insurance_type == "life" )
      insurance_type = "Life Insurance"
    end
    # Get all agency codes for the insurance type
    @agency_codes = AgencyCode.where(insurance_type: insurance_type)
                             .order(:agent_name)

    respond_to do |format|
      format.json do
        render json: {
          success: true,
          agents: @agency_codes.map do |code|
            {
              id: code.id,
              agent_name: code.agent_name,
              code: code.code,
              company_name: code.company_name,
              display_name: "#{code.agent_name} - #{code.code}"
            }
          end
        }
      end
    end
  rescue => e
    respond_to do |format|
      format.json do
        render json: {
          success: false,
          message: "Error fetching agents: #{e.message}"
        }, status: :internal_server_error
      end
    end
  end

  # GET /admin/agency_codes/companies_for_agent - API endpoint for fetching companies for selected agent
  def companies_for_agent
    agent_name = params[:agent_name]
    insurance_type = params[:insurance_type] || 'Life Insurance'

    if agent_name.present?
      # Get all companies for this agent and insurance type (PostgreSQL compatible)
      @agency_codes = AgencyCode.where(agent_name: agent_name, insurance_type: insurance_type)
                               .select('company_name, MIN(id) as id')
                               .group(:company_name)
                               .order(:company_name)
    else
      @agency_codes = AgencyCode.none
    end

    respond_to do |format|
      format.json do
        render json: {
          success: true,
          companies: @agency_codes.map do |code|
            {
              id: code.id,
              company_name: code.company_name
            }
          end
        }
      end
    end
  rescue => e
    respond_to do |format|
      format.json do
        render json: {
          success: false,
          message: "Error fetching companies: #{e.message}"
        }, status: :internal_server_error
      end
    end
  end

  # GET /admin/agency_codes/all_brokers - API endpoint for fetching all brokers when Broking is selected
  def all_brokers
    # Get all active brokers
    @brokers = Broker.active.order(:name)

    respond_to do |format|
      format.json do
        render json: {
          success: true,
          brokers: @brokers.map do |broker|
            {
              id: broker.id,
              name: broker.name
            }
          end
        }
      end
    end
  rescue => e
    respond_to do |format|
      format.json do
        render json: {
          success: false,
          message: "Error fetching brokers: #{e.message}"
        }, status: :internal_server_error
      end
    end
  end

  # GET /admin/agency_codes/all_codes - API endpoint for fetching all unique codes when Direct is selected
  def all_codes
    insurance_type = params[:insurance_type] || 'Life Insurance'

    # Get all unique codes for the insurance type
    @agency_codes = AgencyCode.where(insurance_type: insurance_type)
                             .select('code, MIN(id) as id')
                             .where.not(code: [nil, ''])
                             .group(:code)
                             .order(:code)

    respond_to do |format|
      format.json do
        render json: {
          success: true,
          codes: @agency_codes.map do |code_record|
            {
              id: code_record.id,
              code: code_record.code
            }
          end
        }
      end
    end
  rescue => e
    respond_to do |format|
      format.json do
        render json: {
          success: false,
          message: "Error fetching codes: #{e.message}"
        }, status: :internal_server_error
      end
    end
  end

  # GET /admin/agency_codes/agents_for_code - API endpoint for fetching agents for selected code
  def agents_for_code
    code = params[:code]
    insurance_type = params[:insurance_type] || 'Life Insurance'

    if code.present?
      # Get all agents for this code and insurance type
      @agency_codes = AgencyCode.where(code: code, insurance_type: insurance_type)
                               .select('agent_name, MIN(id) as id, code, company_name')
                               .group(:agent_name, :code, :company_name)
                               .order(:agent_name)
    else
      @agency_codes = AgencyCode.none
    end

    respond_to do |format|
      format.json do
        render json: {
          success: true,
          agents: @agency_codes.map do |code_record|
            {
              id: code_record.id,
              agent_name: code_record.agent_name,
              code: code_record.code,
              company_name: code_record.company_name,
              display_name: "#{code_record.agent_name} - #{code_record.code}"
            }
          end
        }
      end
    end
  rescue => e
    respond_to do |format|
      format.json do
        render json: {
          success: false,
          message: "Error fetching agents for code: #{e.message}"
        }, status: :internal_server_error
      end
    end
  end

  # GET /admin/agency_codes/companies_for_broker - API endpoint for fetching companies for selected broker
  def companies_for_broker
    broker_id = params[:broker_id]
    insurance_type = params[:insurance_type] || 'Life Insurance'  # Default to Life if not specified

    if broker_id.present?
      # Get all companies for this broker, filtered by insurance type
      broker = Broker.find_by(id: broker_id)

      # First try to get companies from agency codes linked to this broker and insurance type
      agency_codes = AgencyCode.where(broker_id: broker_id, insurance_type: insurance_type)
                              .select('company_name')
                              .group(:company_name)
                              .order(:company_name)

      if agency_codes.any?
        companies = agency_codes.map(&:company_name)
      elsif broker&.respond_to?(:insurance_company) && broker.insurance_company
        # Fallback to broker's direct insurance company if it matches the insurance type
        company_name = broker.insurance_company.name
        # Only include the company if it's of the correct type
        if insurance_type_matches?(company_name, insurance_type)
          companies = [company_name]
        else
          companies = []
        end
      else
        # If no specific associations found, return available companies for the insurance type
        # This ensures users can still select companies even if broker associations are not set up
        type_agency_codes = AgencyCode.where(insurance_type: insurance_type)
                                     .select('company_name')
                                     .group(:company_name)
                                     .order(:company_name)
        companies = type_agency_codes.map(&:company_name)

        # If still no companies, fallback to companies from concern based on insurance type
        if companies.empty?
          companies = case insurance_type.to_s.downcase
                     when 'life insurance', 'life'
                       life_insurance_companies
                     when 'health insurance', 'health'
                       health_insurance_companies
                     when 'motor and other insurance', 'motor', 'general'
                       motor_insurance_companies
                     else
                       insurance_companies_list
                     end
        end
      end
    else
      companies = []
    end

    respond_to do |format|
      format.json do
        render json: {
          success: true,
          companies: companies.map.with_index do |company, index|
            {
              id: "broker_#{broker_id}_company_#{index}",
              company_name: company
            }
          end
        }
      end
    end
  rescue => e
    respond_to do |format|
      format.json do
        render json: {
          success: false,
          message: "Error fetching companies for broker: #{e.message}"
        }, status: :internal_server_error
      end
    end
  end

  # GET /admin/agency_codes/all_companies - API endpoint for fetching ALL companies for Broking mode
  def all_companies
    # Get all insurance companies from the InsuranceCompany table
    # This shows the same companies as in the admin sidebar
    companies = InsuranceCompany.order(:name).pluck(:name).compact.reject(&:blank?)

    respond_to do |format|
      format.json do
        render json: {
          success: true,
          companies: companies,
          count: companies.length
        }
      end
    end
  rescue => e
    respond_to do |format|
      format.json do
        render json: {
          success: false,
          message: "Error fetching all companies: #{e.message}"
        }, status: :internal_server_error
      end
    end
  end

  # GET /admin/agency_codes/companies_by_type - API endpoint for fetching companies by insurance type
  def companies_by_type
    insurance_type = params[:insurance_type]
    agency_code_id = params[:agency_code_id] # For edit mode, to include current company
    if insurance_type.present?
      # Map frontend insurance type to database insurance_type values
      db_insurance_type = case insurance_type.to_s.downcase
                         when 'health insurance', 'health', 'Health Insurance'
                           'health'
                         when 'life insurance', 'life', 'Life Insurance'
                           'life'
                         when 'motor and other insurance', 'motor', 'general'
                           'motor_other'
                         else
                           'motor_other'
                         end
      if db_insurance_type
        # Get companies from InsuranceCompany model based on insurance_type
        companies = InsuranceCompany.where(insurance_type: db_insurance_type)
                                  .where(status: true)
                                  .order('LOWER(name) ASC')
                                  .pluck(:name)
                                  .compact
                                  .reject(&:blank?)
      else
        # If no specific type matched, return all active companies
        companies = InsuranceCompany.where(status: true)
                                  .order('LOWER(name) ASC')
                                  .pluck(:name)
                                  .compact
                                  .reject(&:blank?)
      end
    else
      # Return all active companies if no type specified
      companies = InsuranceCompany.where(status: true)
                                .order('LOWER(name) ASC')
                                .pluck(:name)
                                .compact
                                .reject(&:blank?)
    end

    # If agency_code_id is provided (edit mode), include the current company name
    if agency_code_id.present?
      agency_code = AgencyCode.find_by(id: agency_code_id)
      if agency_code&.company_name.present? && !companies.include?(agency_code.company_name)
        companies << agency_code.company_name
        companies.sort_by!(&:downcase)
      end
    end

    respond_to do |format|
      format.json do
        render json: {
          success: true,
          companies: companies,
          insurance_type: insurance_type,
          db_insurance_type: db_insurance_type,
          count: companies.length
        }
      end
    end
  rescue => e
    respond_to do |format|
      format.json do
        render json: {
          success: false,
          message: "Error fetching companies by type: #{e.message}"
        }, status: :internal_server_error
      end
    end
  end

  # GET /admin/agency_codes/company_for_agency_code - API endpoint for fetching company for specific agency code
  def company_for_agency_code
    agency_code_id = params[:agency_code_id]

    if agency_code_id.present?
      agency_code = AgencyCode.find_by(id: agency_code_id)

      if agency_code&.company_name.present?
        respond_to do |format|
          format.json do
            render json: {
              success: true,
              company_name: agency_code.company_name,
              agency_code_id: agency_code.id,
              agent_name: agency_code.agent_name,
              code: agency_code.code
            }
          end
        end
      else
        respond_to do |format|
          format.json do
            render json: {
              success: false,
              message: "No company found for this agency code"
            }, status: :not_found
          end
        end
      end
    else
      respond_to do |format|
        format.json do
          render json: {
            success: false,
            message: "Agency code ID is required"
          }, status: :bad_request
        end
      end
    end
  rescue => e
    respond_to do |format|
      format.json do
        render json: {
          success: false,
          message: "Error fetching company for agency code: #{e.message}"
        }, status: :internal_server_error
      end
    end
  end

  private

  def set_agency_code
    @agency_code = AgencyCode.find(params[:id])
  end

  def agency_code_params
    params.require(:agency_code).permit(:insurance_type, :company_name, :agent_name, :code)
  end

  # Helper method to check if an insurance company matches the insurance type
  def insurance_type_matches?(company_name, insurance_type)
    case insurance_type.to_s.downcase
    when 'life insurance', 'life'
      life_insurance_companies.include?(company_name)
    when 'health insurance', 'health'
      health_insurance_companies.include?(company_name)
    when 'motor and other insurance', 'motor', 'general'
      motor_insurance_companies.include?(company_name)
    else
      true # For other types, allow any company
    end
  end

  # Helper method to get insurance companies for a specific insurance type
  def get_companies_for_insurance_type(insurance_type)
    # Initialize as empty array to ensure it's never nil
    companies = []

    # If insurance type is provided, load companies for that type
    if insurance_type.present?
      companies = case insurance_type.to_s.downcase
                 when 'health insurance', 'health'
                   AgencyCode.health_insurance_companies.map { |company| company[:name] }
                 when 'life insurance', 'life'
                   AgencyCode.life_insurance_companies.map { |company| company[:name] }
                 when 'motor and other insurance', 'motor', 'general'
                   AgencyCode.general_insurance_companies.map { |company| company[:name] }
                 else
                   AgencyCode.insurance_company_names
                 end
    end

    # Ensure we always return a sorted array (never nil)
    companies.present? ? companies.sort : []
  end

  # AJAX endpoint for fetching insurance companies for a specific agency code
  def insurance_companies
    agency_code = AgencyCode.find(params[:id])
    companies = get_companies_for_insurance_type(agency_code.insurance_type)
    render json: companies
  rescue ActiveRecord::RecordNotFound
    render json: [], status: :not_found
  end

  # Get all companies sorted alphabetically
  def get_all_companies_sorted
    # Get companies from database first (active insurance companies)
    db_companies = InsuranceCompany.where(status: true)
                                 .order('LOWER(name) ASC')
                                 .pluck(:name)
                                 .compact
                                 .reject(&:blank?)

    # Get companies from agency codes if database is empty
    if db_companies.empty?
      agency_companies = AgencyCode.select(:company_name)
                                 .where.not(company_name: [nil, ''])
                                 .group(:company_name)
                                 .order('LOWER(company_name) ASC')
                                 .pluck(:company_name)
                                 .compact
                                 .reject(&:blank?)

      return agency_companies
    end

    # Return database companies sorted alphabetically
    db_companies
  end
end