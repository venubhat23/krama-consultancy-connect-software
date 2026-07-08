class Admin::InsuranceCompaniesController < Admin::ApplicationController
  before_action :set_insurance_company, only: [:show, :edit, :update, :destroy]
  before_action :set_filter_params, only: [:index]

  def index
    # Build filtered companies query directly
    @insurance_companies = build_filtered_companies_query

    # Use cached statistics separately to avoid serialization issues
    stats_cache_key = [
      'insurance_companies_stats',
      InsuranceCompany.maximum(:updated_at)&.to_i
    ].compact.join('-')

    stats = Rails.cache.fetch(stats_cache_key, expires_in: 10.minutes) do
      if InsuranceCompany.respond_to?(:statistics_cached)
        InsuranceCompany.statistics_cached
      else
        # Fallback to basic counts
        {
          total: InsuranceCompany.count,
          life: InsuranceCompany.where(insurance_type: 'life').count,
          health: InsuranceCompany.where(insurance_type: 'health').count,
          motor_other: InsuranceCompany.where(insurance_type: 'motor_other').count
        }
      end
    end

    @total_companies = stats[:total] || 0
    @life_companies = stats[:life] || 0
    @health_companies = stats[:health] || 0
    @general_companies = stats[:motor_other] || 0

  rescue NameError
    redirect_to admin_customers_path, alert: 'Insurance Companies functionality not yet implemented.'
  end

  def show
    # Include associations to prevent N+1 queries in views
    @insurance_company = InsuranceCompany.includes(:brokers).find(params[:id])
  end

  def new
    @insurance_company = InsuranceCompany.new
    set_form_data
  rescue NameError
    redirect_to admin_customers_path, alert: 'Insurance Companies functionality not yet implemented.'
  end

  def edit
    set_form_data
  end

  def create
    @insurance_company = InsuranceCompany.new(insurance_company_params)

    respond_to do |format|
      if @insurance_company.save
        format.html {
          redirect_to admin_insurance_company_path(@insurance_company),
          notice: 'Insurance company was successfully created.'
        }
        format.json { render :show, status: :created, location: @insurance_company }
      else
        set_form_data
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @insurance_company.errors, status: :unprocessable_entity }
      end
    end
  rescue NameError
    redirect_to admin_customers_path, alert: 'Insurance Companies functionality not yet implemented.'
  end

  def update
    respond_to do |format|
      if @insurance_company.update(insurance_company_params)
        format.html {
          redirect_to admin_insurance_company_path(@insurance_company),
          notice: 'Insurance company was successfully updated.'
        }
        format.json { render :show, status: :ok, location: @insurance_company }
      else
        set_form_data
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @insurance_company.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    can_delete = @insurance_company.can_be_deleted?
    company_name = @insurance_company.name

    respond_to do |format|
      if can_delete && @insurance_company.destroy
        format.html {
          redirect_to admin_insurance_companies_path,
          notice: "#{company_name} was successfully deleted."
        }
        format.json { head :no_content }
      else
        error_message = can_delete ?
          "Failed to delete #{company_name}." :
          "Cannot delete #{company_name}. It has associated records."

        format.html {
          redirect_to admin_insurance_companies_path,
          alert: error_message
        }
        format.json {
          render json: { error: error_message },
          status: :unprocessable_entity
        }
      end
    end
  end

  # API endpoints for faster AJAX operations
  def search
    @insurance_companies = build_filtered_companies_query
    render json: {
      companies: @insurance_companies.map { |c| company_json(c) },
      total: @insurance_companies.count,
      page: @page,
      per_page: @per_page
    }
  end

  def statistics
    render json: InsuranceCompany.statistics_cached
  end

  private

  def set_insurance_company
    @insurance_company = InsuranceCompany.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_insurance_companies_path, alert: 'Insurance company not found.'
  rescue NameError
    redirect_to admin_customers_path, alert: 'Insurance Companies functionality not yet implemented.'
  end

  def set_filter_params
    @current_tab = params[:tab] || 'all'
    @search_query = params[:search]&.strip
    @page = [params[:page].to_i, 1].max
    @per_page = [params[:per_page]&.to_i || 20, 100].min # Max 100 per page
  end

  def build_filtered_companies_query
    # Map tab to insurance type
    insurance_type = case @current_tab
    when 'life' then 'life'
    when 'health' then 'health'
    when 'general' then 'motor_other'
    else nil
    end

    # Use optimized model method
    companies = InsuranceCompany.search_and_filter(
      search_query: @search_query,
      insurance_type: insurance_type,
      page: @page,
      per_page: @per_page
    )

    # Handle pagination if using Kaminari
    if defined?(Kaminari) && companies.respond_to?(:page)
      companies.page(@page).per(@per_page)
    else
      companies
    end
  end

  def set_form_data
    # Cache form data for better performance
    @insurance_types = Rails.cache.fetch('insurance_types', expires_in: 1.hour) do
      [
        ['Health Insurance', 'health'],
        ['Life Insurance', 'life'],
        ['Motor and Other Insurance', 'motor_other']
      ]
    end
  end

  def insurance_company_params
    params.require(:insurance_company).permit(
      :name, :code, :contact_person, :email, :mobile,
      :address, :status, :insurance_type
    )
  end

  def company_json(company)
    {
      id: company.id,
      name: company.name,
      code: company.code,
      insurance_type: company.insurance_type,
      display_type: company.display_type,
      status: company.status,
      display_status: company.display_status,
      contact_person: company.contact_person,
      email: company.email,
      mobile: company.mobile,
      created_at: company.created_at.iso8601,
      updated_at: company.updated_at.iso8601
    }
  end
end