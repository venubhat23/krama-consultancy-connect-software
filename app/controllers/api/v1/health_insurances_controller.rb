class Api::V1::HealthInsurancesController < Api::V1::ApplicationController
  before_action :set_health_insurance, only: [:show, :update, :destroy]

  # GET /api/v1/health_insurances
  def index
    @health_insurances = HealthInsurance.includes(:customer, :sub_agent, :agency_code, :broker, :health_insurance_members)

    # Search functionality
    if params[:search].present?
      @health_insurances = @health_insurances.search_health_policies(params[:search])
    end

    # Filter by status
    case params[:status]
    when 'active'
      @health_insurances = @health_insurances.active
    when 'expired'
      @health_insurances = @health_insurances.expired
    when 'expiring_soon'
      @health_insurances = @health_insurances.expiring_soon
    end

    # Filter by insurance type
    if params[:insurance_type].present?
      @health_insurances = @health_insurances.where(insurance_type: params[:insurance_type])
    end

    # Filter by insurance company
    if params[:company].present?
      @health_insurances = @health_insurances.where(insurance_company_name: params[:company])
    end

    # Filter by date range
    if params[:start_date].present? && params[:end_date].present?
      @health_insurances = @health_insurances.where(
        policy_start_date: Date.parse(params[:start_date])..Date.parse(params[:end_date])
      )
    end

    # Pagination
    @health_insurances = @health_insurances.order(created_at: :desc)
    @health_insurances = @health_insurances.limit(params[:limit] || 20)
    @health_insurances = @health_insurances.offset(params[:offset] || 0)

    render json: {
      success: true,
      data: @health_insurances.map { |policy| policy_json(policy) },
      meta: {
        total_count: @health_insurances.count,
        current_page: (params[:offset].to_i / (params[:limit] || 20).to_i) + 1,
        total_pages: (@health_insurances.count / (params[:limit] || 20).to_f).ceil
      }
    }
  end

  # GET /api/v1/health_insurances/:id
  def show
    render json: {
      success: true,
      data: policy_detail_json(@health_insurance)
    }
  end

  # POST /api/v1/health_insurances
  def create
    @health_insurance = HealthInsurance.new(health_insurance_params)

    if @health_insurance.save
      render json: {
        success: true,
        message: 'Health insurance policy created successfully',
        data: policy_detail_json(@health_insurance)
      }, status: :created
    else
      render json: {
        success: false,
        message: 'Failed to create health insurance policy',
        errors: @health_insurance.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/health_insurances/:id
  def update
    if @health_insurance.update(health_insurance_params)
      render json: {
        success: true,
        message: 'Health insurance policy updated successfully',
        data: policy_detail_json(@health_insurance)
      }
    else
      render json: {
        success: false,
        message: 'Failed to update health insurance policy',
        errors: @health_insurance.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/health_insurances/:id
  def destroy
    if @health_insurance.destroy
      render json: {
        success: true,
        message: 'Health insurance policy deleted successfully'
      }
    else
      render json: {
        success: false,
        message: 'Failed to delete health insurance policy'
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/health_insurances/statistics
  def statistics
    policies = HealthInsurance.all

    render json: {
      success: true,
      data: {
        total_policies: policies.count,
        active_policies: policies.active.count,
        expired_policies: policies.expired.count,
        expiring_soon: policies.expiring_soon.count,
        total_premium: policies.sum(:total_premium).to_f,
        total_sum_insured: policies.sum(:sum_insured).to_f,
        total_commission: policies.sum(:commission_amount).to_f,
        by_insurance_type: policies.group(:insurance_type).count,
        by_company: policies.group(:insurance_company_name).count,
        by_policy_type: policies.group(:policy_type).count,
        recent_policies: policies.order(created_at: :desc).limit(5).map { |p| policy_json(p) }
      }
    }
  end

  # GET /api/v1/health_insurances/form_data
  def form_data
    render json: {
      success: true,
      data: {
        customers: Customer.active.order(:first_name, :last_name, :company_name).map do |c|
          {
            id: c.id,
            name: c.display_name,
            email: c.email,
            mobile: c.mobile,
            type: c.customer_type
          }
        end,
        sub_agents: SubAgent.active.order(:first_name, :last_name).map do |agent|
          {
            id: agent.id,
            name: agent.display_name,
            email: agent.email,
            mobile: agent.mobile
          }
        end,
        agency_codes: AgencyCode.where(insurance_type: 'Health').map do |code|
          {
            id: code.id,
            display_name: "#{code.company_name} - #{code.code}",
            company_name: code.company_name,
            code: code.code
          }
        end,
        brokers: Broker.active.order(:name).map do |broker|
          {
            id: broker.id,
            name: broker.name
          }
        end,
        insurance_companies: InsuranceCompanyHelper.company_names,
        policy_types: HealthInsurance::POLICY_TYPES,
        insurance_types: HealthInsurance::INSURANCE_TYPES,
        payment_modes: HealthInsurance::PAYMENT_MODES,
        relationships: HealthInsuranceMember::RELATIONSHIPS
      }
    }
  end

  # GET /api/v1/health_insurances/policy_holder_options
  def policy_holder_options
    customer = Customer.find(params[:customer_id]) if params[:customer_id].present?
    options = [{ label: 'Self', value: 'Self' }]

    if customer&.family_members&.any?
      customer.family_members.each do |member|
        options << {
          label: "#{member.name} (#{member.relationship.humanize})",
          value: member.name,
          relationship: member.relationship,
          age: member.age
        }
      end
    end

    render json: {
      success: true,
      data: { options: options }
    }
  end

  private

  def set_health_insurance
    @health_insurance = HealthInsurance.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      message: 'Health insurance policy not found'
    }, status: :not_found
  end

  def health_insurance_params
    params.require(:health_insurance).permit(
      :customer_id, :sub_agent_id, :agency_code_id, :broker_id,
      :policy_holder, :insurance_company_name, :policy_type, :insurance_type,
      :plan_name, :policy_number, :policy_booking_date, :policy_start_date,
      :policy_end_date, :policy_term, :payment_mode, :claim_process,
      :sum_insured, :net_premium, :gst_percentage, :total_premium,
      :main_agent_commission_percentage, :commission_amount, :tds_percentage,
      :tds_amount, :after_tds_value, :reference_by_name,
      health_insurance_members_attributes: [
        :id, :member_name, :age, :relationship, :sum_insured, :_destroy
      ]
    )
  end

  def policy_json(policy)
    {
      id: policy.id,
      policy_number: policy.policy_number,
      customer_name: policy.customer.display_name,
      customer_email: policy.customer.email,
      customer_mobile: policy.customer.mobile,
      insurance_company_name: policy.insurance_company_name,
      insurance_type: policy.insurance_type,
      policy_type: policy.policy_type,
      plan_name: policy.plan_name,
      sum_insured: policy.sum_insured,
      net_premium: policy.net_premium,
      total_premium: policy.total_premium,
      policy_start_date: policy.policy_start_date,
      policy_end_date: policy.policy_end_date,
      status: policy.active? ? 'active' : (policy.expired? ? 'expired' : 'pending'),
      days_until_expiry: policy.days_until_expiry,
      affiliate_name: policy.affiliate_name,
      created_at: policy.created_at,
      updated_at: policy.updated_at
    }
  end

  def policy_detail_json(policy)
    policy_json(policy).merge({
      policy_holder: policy.policy_holder,
      policy_booking_date: policy.policy_booking_date,
      policy_term: policy.policy_term,
      payment_mode: policy.payment_mode,
      claim_process: policy.claim_process,
      gst_percentage: policy.gst_percentage,
      main_agent_commission_percentage: policy.main_agent_commission_percentage,
      commission_amount: policy.commission_amount,
      tds_percentage: policy.tds_percentage,
      tds_amount: policy.tds_amount,
      after_tds_value: policy.after_tds_value,
      reference_by_name: policy.reference_by_name,
      customer: {
        id: policy.customer.id,
        name: policy.customer.display_name,
        email: policy.customer.email,
        mobile: policy.customer.mobile,
        type: policy.customer.customer_type
      },
      sub_agent: policy.sub_agent ? {
        id: policy.sub_agent.id,
        name: policy.sub_agent.display_name,
        email: policy.sub_agent.email,
        mobile: policy.sub_agent.mobile
      } : nil,
      agency_code: policy.agency_code ? {
        id: policy.agency_code.id,
        company_name: policy.agency_code.company_name,
        code: policy.agency_code.code
      } : nil,
      broker: policy.broker ? {
        id: policy.broker.id,
        name: policy.broker.name
      } : nil,
      family_members: policy.health_insurance_members.map do |member|
        {
          id: member.id,
          member_name: member.member_name,
          age: member.age,
          relationship: member.relationship,
          sum_insured: member.sum_insured
        }
      end,
      documents: policy.policy_documents.attached? ?
        policy.policy_documents.map { |doc| rails_blob_url(doc) } : [],
      additional_documents: policy.documents.attached? ?
        policy.documents.map { |doc| rails_blob_url(doc) } : []
    })
  end
end