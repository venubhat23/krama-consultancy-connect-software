class Admin::PoliciesController < Admin::ApplicationController
  before_action :set_policy, only: [:show, :edit, :update, :destroy, :download_pdf]

  # GET /admin/policies
  def index
    @policies = Policy.includes(:customer, :insurance_company, :user)

    # Search functionality
    if params[:search].present?
      @policies = @policies.joins(:customer).where(
        "customers.first_name ILIKE ? OR customers.last_name ILIKE ? OR customers.company_name ILIKE ? OR policies.policy_number ILIKE ?",
        "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%"
      )
    end

    # Filter by insurance type
    if params[:insurance_type].present?
      @policies = @policies.where(insurance_type: params[:insurance_type])
    end

    # Filter by status
    case params[:status]
    when 'active'
      @policies = @policies.active
    when 'expired'
      @policies = @policies.expired
    when 'expiring_soon'
      @policies = @policies.expiring_soon
    end

    @policies = @policies.order(created_at: :desc).page(params[:page])

    # Statistics
    @total_policies = Policy.count
    @active_policies = Policy.active.count
    @total_premium = Policy.active.sum(:total_premium)
    @total_sum_insured = Policy.active.sum(:sum_insured)
  end

  # GET /admin/policies/1
  def show
  end

  # GET /admin/policies/new
  def new
    @policy = Policy.new
    @customers = Customer.active.order(:first_name)
    @insurance_companies = InsuranceCompany.active.order(:name) if defined?(InsuranceCompany)
  end

  # GET /admin/policies/1/edit
  def edit
    @customers = Customer.active.order(:first_name)
    @insurance_companies = InsuranceCompany.active.order(:name) if defined?(InsuranceCompany)
  end

  # POST /admin/policies
  def create
    @policy = Policy.new(policy_params)
    @policy.user = current_user

    if @policy.save
      redirect_to admin_policy_path(@policy), notice: 'Policy was successfully created.'
    else
      @customers = Customer.active.order(:first_name)
      @insurance_companies = InsuranceCompany.active.order(:name) if defined?(InsuranceCompany)
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /admin/policies/1
  def update
    if @policy.update(policy_params)
      redirect_to admin_policy_path(@policy), notice: 'Policy was successfully updated.'
    else
      @customers = Customer.active.order(:first_name)
      @insurance_companies = InsuranceCompany.active.order(:name) if defined?(InsuranceCompany)
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/policies/1
  def destroy
    @policy.destroy
    redirect_to admin_policies_path, notice: 'Policy was successfully deleted.'
  end

  # GET /admin/policies/1/download_pdf
  def download_pdf
    # PDF generation logic would go here
    redirect_to admin_policy_path(@policy), alert: 'PDF generation not implemented yet.'
  end

  private

  def set_policy
    @policy = Policy.find(params[:id])
  end

  def policy_params
    params.require(:policy).permit(
      :customer_id, :insurance_company_id, :policy_number, :insurance_type,
      :policy_type, :sum_insured, :premium_amount, :total_premium, :premium_frequency,
      :start_date, :end_date, :nominee_name, :nominee_relation, :status,
      :additional_details, documents: []
    )
  end
end