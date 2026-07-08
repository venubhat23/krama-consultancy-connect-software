class Api::V1::LifeInsurancesController < Api::V1::ApplicationController
  before_action :set_life_insurance, only: [:show, :update, :destroy]

  # GET /api/v1/life_insurances
  def index
    @life_insurances = LifeInsurance.includes(:customer, :sub_agent, :agency_code, :broker)

    # Search functionality
    if params[:search].present?
      @life_insurances = @life_insurances.search_life_policies(params[:search])
    end

    # Filter by status
    case params[:status]
    when 'active'
      @life_insurances = @life_insurances.active
    when 'expired'
      @life_insurances = @life_insurances.expired
    when 'expiring_soon'
      @life_insurances = @life_insurances.expiring_soon
    end

    # Filter by policy type
    if params[:policy_type].present?
      @life_insurances = @life_insurances.where(policy_type: params[:policy_type])
    end

    # Filter by insurance company
    if params[:company].present?
      @life_insurances = @life_insurances.where(insurance_company_name: params[:company])
    end

    # Filter by date range
    if params[:start_date].present? && params[:end_date].present?
      @life_insurances = @life_insurances.where(
        policy_start_date: Date.parse(params[:start_date])..Date.parse(params[:end_date])
      )
    end

    # Pagination
    @life_insurances = @life_insurances.order(created_at: :desc)
    @life_insurances = @life_insurances.limit(params[:limit] || 20)
    @life_insurances = @life_insurances.offset(params[:offset] || 0)

    render json: {
      success: true,
      data: @life_insurances.map { |policy| policy_json(policy) },
      meta: {
        total_count: @life_insurances.count,
        current_page: (params[:offset].to_i / (params[:limit] || 20).to_i) + 1,
        total_pages: (@life_insurances.count / (params[:limit] || 20).to_f).ceil
      }
    }
  end

  # GET /api/v1/life_insurances/:id
  def show
    render json: {
      success: true,
      data: policy_detail_json(@life_insurance)
    }
  end

  # POST /api/v1/life_insurances
  def create
    @life_insurance = LifeInsurance.new(life_insurance_params)

    if @life_insurance.save
      render json: {
        success: true,
        message: 'Life insurance policy created successfully',
        data: policy_detail_json(@life_insurance)
      }, status: :created
    else
      render json: {
        success: false,
        message: 'Failed to create life insurance policy',
        errors: @life_insurance.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/life_insurances/:id
  def update
    if @life_insurance.update(life_insurance_params)
      render json: {
        success: true,
        message: 'Life insurance policy updated successfully',
        data: policy_detail_json(@life_insurance)
      }
    else
      render json: {
        success: false,
        message: 'Failed to update life insurance policy',
        errors: @life_insurance.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/life_insurances/:id
  def destroy
    if @life_insurance.destroy
      render json: {
        success: true,
        message: 'Life insurance policy deleted successfully'
      }
    else
      render json: {
        success: false,
        message: 'Failed to delete life insurance policy'
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/life_insurances/statistics
  def statistics
    policies = LifeInsurance.all

    render json: {
      success: true,
      data: {
        total_policies: policies.count,
        active_policies: policies.active.count,
        expired_policies: policies.expired.count,
        expiring_soon: policies.expiring_soon.count,
        new_policies: policies.new_policies.count,
        renewals: policies.renewals.count,
        total_premium: policies.sum(:total_premium).to_f,
        total_sum_insured: policies.sum(:sum_insured).to_f,
        total_commission: policies.sum(:commission_amount).to_f,
        total_riders: policies.sum(:term_rider_amount).to_f + policies.sum(:critical_illness_rider_amount).to_f +
                     policies.sum(:accident_rider_amount).to_f + policies.sum(:pwb_rider_amount).to_f +
                     policies.sum(:other_rider_amount).to_f,
        by_policy_type: policies.group(:policy_type).count,
        by_company: policies.group(:insurance_company_name).count,
        by_payment_mode: policies.group(:payment_mode).count,
        recent_policies: policies.order(created_at: :desc).limit(5).map { |p| policy_json(p) }
      }
    }
  end

  # GET /api/v1/life_insurances/form_data
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
        agency_codes: AgencyCode.where(insurance_type: 'Life').map do |code|
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
        policy_types: LifeInsurance::POLICY_TYPES,
        payment_modes: LifeInsurance::PAYMENT_MODES,
        relationships: LifeInsurance::RELATIONSHIPS,
        account_types: LifeInsurance::ACCOUNT_TYPES,
        document_types: LifeInsurance::DOCUMENT_TYPES
      }
    }
  end

  # GET /api/v1/life_insurances/policy_holder_options
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

  def set_life_insurance
    @life_insurance = LifeInsurance.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      message: 'Life insurance policy not found'
    }, status: :not_found
  end

  def life_insurance_params
    params.require(:life_insurance).permit(
      :customer_id, :sub_agent_id, :agency_code_id, :broker_id,
      :policy_holder, :insured_name, :insurance_company_name, :policy_type,
      :payment_mode, :policy_number, :policy_booking_date, :policy_start_date,
      :policy_end_date, :risk_start_date, :policy_term, :premium_payment_term,
      :plan_name, :sum_insured, :net_premium, :first_year_gst_percentage,
      :second_year_gst_percentage, :third_year_gst_percentage, :total_premium,
      :term_rider_amount, :term_rider_note, :critical_illness_rider_amount,
      :critical_illness_rider_note, :accident_rider_amount, :accident_rider_note,
      :pwb_rider_amount, :pwb_rider_note, :other_rider_amount, :other_rider_note,
      :nominee_name, :nominee_relationship, :nominee_age, :bank_name,
      :account_type, :account_number, :ifsc_code, :account_holder_name,
      :reference_by_name, :broker_name, :bonus, :fund, :extra_note,
      :main_agent_commission_percentage, :commission_amount, :tds_percentage,
      :tds_amount, :after_tds_value, :installment_autopay_start_date,
      :installment_autopay_end_date, :active
    )
  end

  def policy_json(policy)
    {
      id: policy.id,
      policy_number: policy.policy_number,
      customer_name: policy.customer.display_name,
      customer_email: policy.customer.email,
      customer_mobile: policy.customer.mobile,
      insured_name: policy.insured_name,
      insurance_company_name: policy.insurance_company_name,
      policy_type: policy.policy_type,
      plan_name: policy.plan_name,
      sum_insured: policy.sum_insured,
      net_premium: policy.net_premium,
      total_premium: policy.total_premium,
      policy_start_date: policy.policy_start_date,
      policy_end_date: policy.policy_end_date,
      status: policy.status,
      days_until_expiry: policy.days_until_expiry,
      affiliate_name: policy.affiliate_name,
      total_riders: policy.total_rider_amount,
      created_at: policy.created_at,
      updated_at: policy.updated_at
    }
  end

  def policy_detail_json(policy)
    policy_json(policy).merge({
      policy_holder: policy.policy_holder,
      policy_booking_date: policy.policy_booking_date,
      risk_start_date: policy.risk_start_date,
      policy_term: policy.policy_term,
      premium_payment_term: policy.premium_payment_term,
      payment_mode: policy.payment_mode,
      first_year_gst_percentage: policy.first_year_gst_percentage,
      second_year_gst_percentage: policy.second_year_gst_percentage,
      third_year_gst_percentage: policy.third_year_gst_percentage,

      # Rider details
      term_rider_amount: policy.term_rider_amount,
      term_rider_note: policy.term_rider_note,
      critical_illness_rider_amount: policy.critical_illness_rider_amount,
      critical_illness_rider_note: policy.critical_illness_rider_note,
      accident_rider_amount: policy.accident_rider_amount,
      accident_rider_note: policy.accident_rider_note,
      pwb_rider_amount: policy.pwb_rider_amount,
      pwb_rider_note: policy.pwb_rider_note,
      other_rider_amount: policy.other_rider_amount,
      other_rider_note: policy.other_rider_note,

      # Nominee details
      nominee_name: policy.nominee_name,
      nominee_relationship: policy.nominee_relationship,
      nominee_age: policy.nominee_age,

      # Bank details
      bank_name: policy.bank_name,
      account_type: policy.account_type,
      account_number: policy.account_number,
      ifsc_code: policy.ifsc_code,
      account_holder_name: policy.account_holder_name,

      # Other details
      reference_by_name: policy.reference_by_name,
      broker_name: policy.broker_name,
      bonus: policy.bonus,
      fund: policy.fund,
      extra_note: policy.extra_note,

      # Commission details
      main_agent_commission_percentage: policy.main_agent_commission_percentage,
      commission_amount: policy.commission_amount,
      tds_percentage: policy.tds_percentage,
      tds_amount: policy.tds_amount,
      after_tds_value: policy.after_tds_value,

      # Autopay details
      installment_autopay_start_date: policy.installment_autopay_start_date,
      installment_autopay_end_date: policy.installment_autopay_end_date,

      # Associations
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
      documents: policy.policy_documents.attached? ?
        policy.policy_documents.map { |doc| rails_blob_url(doc) } : [],
      additional_documents: policy.documents.attached? ?
        policy.documents.map { |doc| rails_blob_url(doc) } : []
    })
  end
end