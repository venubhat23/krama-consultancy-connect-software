class Api::V1::Mobile::InvestmentsController < Api::V1::Mobile::BaseController
  before_action :authenticate_customer!
  before_action :set_mutual_fund, only: [:show_mutual_fund,  :update_mutual_fund,  :destroy_mutual_fund]
  before_action :set_fd,          only: [:show_fd,           :update_fd,           :destroy_fd]
  before_action :set_other,       only: [:show_other,        :update_other,        :destroy_other]

  # GET /api/v1/mobile/investments/summary
  def summary
    cid = current_customer.id

    mf_scope    = MutualFund.where(customer_id: cid)
    fd_scope    = customer_services('investments_fd')
    other_scope = customer_services('investments_other')

    mf_total    = mf_scope.sum(:amount).to_f
    fd_total    = fd_scope.sum(:amount).to_f
    other_total = other_scope.sum(:amount).to_f
    grand_total = mf_total + fd_total + other_total

    render json: {
      success: true,
      data: {
        total_investments:     mf_scope.count + fd_scope.count + other_scope.count,
        total_invested_amount: format_indian_amount(grand_total),
        total_invested_raw:    grand_total,
        mutual_funds: {
          count:            mf_scope.count,
          total_amount:     format_indian_amount(mf_total),
          total_amount_raw: mf_total,
          active_count:     mf_scope.where(active: true).count,
          drwise_count:     mf_scope.where(is_admin_added: true).count,
          non_drwise_count: mf_scope.where(is_admin_added: false).count
        },
        fixed_deposits: {
          count:            fd_scope.count,
          total_amount:     format_indian_amount(fd_total),
          total_amount_raw: fd_total,
          active_count:     fd_scope.where(status: 'active').count
        },
        other_investments: {
          count:            other_scope.count,
          total_amount:     format_indian_amount(other_total),
          total_amount_raw: other_total,
          active_count:     other_scope.where(status: 'active').count
        }
      }
    }
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # MUTUAL FUNDS
  # ─────────────────────────────────────────────────────────────────────────────

  # GET /api/v1/mobile/investments/mutual_funds
  def mutual_funds
    scope = MutualFund.where(customer_id: current_customer.id)
    scope = scope.where(investment_type: params[:investment_type]) if params[:investment_type].present?
    scope = scope.where(active: params[:active])                   if params[:active].present?
    scope = scope.order(created_at: :desc)

    render json: {
      success: true,
      data: {
        mutual_funds: scope.map { |mf| serialize_mutual_fund(mf) },
        total:        scope.count,
        total_amount: format_indian_amount(scope.sum(:amount))
      }
    }
  end

  # POST /api/v1/mobile/investments/mutual_funds
  # drwise: true  → is_admin_added: true  (appears in DrWise tab in admin)
  # drwise: false → is_customer_added: true (appears in Non-DrWise tab)
  def create_mutual_fund
    return render_missing('investment_type') if params[:investment_type].blank?
    return render_missing('amount')          if params[:amount].blank?

    drwise = params[:drwise].to_s == 'true'

    mf = MutualFund.new(
      customer_id:       current_customer.id,
      investment_type:   params[:investment_type],
      amount:            params[:amount],
      fund_name:         params[:fund_name],
      folio_number:      params[:folio_number],
      plan_name:         params[:plan_name],
      start_date:        parse_date(params[:start_date]),
      maturity_date:     parse_date(params[:maturity_date]),
      active:            true,
      is_admin_added:    drwise,
      is_customer_added: !drwise,
      is_agent_added:    false
    )

    if mf.save
      render json: {
        success: true,
        message: 'Mutual fund added successfully. Our team will review and update details.',
        data:    serialize_mutual_fund(mf)
      }, status: :created
    else
      render json: {
        success: false,
        message: 'Failed to add mutual fund',
        errors:  mf.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/mobile/investments/mutual_funds/:id
  def show_mutual_fund
    render json: { success: true, data: serialize_mutual_fund(@mutual_fund) }
  end

  # PATCH /api/v1/mobile/investments/mutual_funds/:id
  def update_mutual_fund
    attrs = slice_present(
      investment_type: params[:investment_type],
      amount:          params[:amount],
      fund_name:       params[:fund_name],
      folio_number:    params[:folio_number],
      plan_name:       params[:plan_name],
      start_date:      parse_date(params[:start_date]),
      maturity_date:   parse_date(params[:maturity_date]),
      active:          params[:active]
    )

    if @mutual_fund.update(attrs)
      render json: { success: true, message: 'Mutual fund updated', data: serialize_mutual_fund(@mutual_fund) }
    else
      render json: { success: false, message: 'Update failed', errors: @mutual_fund.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/mobile/investments/mutual_funds/:id
  def destroy_mutual_fund
    @mutual_fund.destroy
    render json: { success: true, message: 'Mutual fund removed' }
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # FIXED DEPOSITS
  # ─────────────────────────────────────────────────────────────────────────────

  # GET /api/v1/mobile/investments/fd
  def fd_list
    scope = customer_services('investments_fd').order(created_at: :desc)
    scope = scope.where(status: params[:status]) if params[:status].present?

    render json: {
      success: true,
      data: {
        fixed_deposits: scope.map { |s| serialize_service(s) },
        total:          scope.count,
        total_amount:   format_indian_amount(scope.sum(:amount))
      }
    }
  end

  # POST /api/v1/mobile/investments/fd
  def create_fd
    return render_missing('amount') if params[:amount].blank?

    drwise = params[:drwise].to_s == 'true'

    service = ClientService.new(
      customer_id:      current_customer.id,
      service_type:     'investments_fd',
      amount:           params[:amount],
      status:           params[:status].presence || 'pending',
      reference_number: params[:reference_number],
      start_date:       parse_date(params[:start_date]),
      notes:            params[:notes],
      is_admin_added:    drwise,
      is_customer_added: !drwise,
      is_agent_added:    false
    )

    if service.save
      render json: { success: true, message: 'Fixed deposit added', data: serialize_service(service) }, status: :created
    else
      render json: { success: false, message: 'Failed to add FD', errors: service.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/mobile/investments/fd/:id
  def show_fd
    render json: { success: true, data: serialize_service(@fd) }
  end

  # PATCH /api/v1/mobile/investments/fd/:id
  def update_fd
    update_service(@fd)
  end

  # DELETE /api/v1/mobile/investments/fd/:id
  def destroy_fd
    @fd.destroy
    render json: { success: true, message: 'Fixed deposit removed' }
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # OTHER INVESTMENTS
  # ─────────────────────────────────────────────────────────────────────────────

  # GET /api/v1/mobile/investments/other
  def other_list
    scope = customer_services('investments_other').order(created_at: :desc)
    scope = scope.where(status: params[:status]) if params[:status].present?

    render json: {
      success: true,
      data: {
        other_investments: scope.map { |s| serialize_service(s) },
        total:             scope.count,
        total_amount:      format_indian_amount(scope.sum(:amount))
      }
    }
  end

  # POST /api/v1/mobile/investments/other
  def create_other
    return render_missing('amount') if params[:amount].blank?

    drwise = params[:drwise].to_s == 'true'

    service = ClientService.new(
      customer_id:      current_customer.id,
      service_type:     'investments_other',
      amount:           params[:amount],
      status:           params[:status].presence || 'pending',
      reference_number: params[:reference_number],
      start_date:       parse_date(params[:start_date]),
      notes:            params[:notes],
      is_admin_added:    drwise,
      is_customer_added: !drwise,
      is_agent_added:    false
    )

    if service.save
      render json: { success: true, message: 'Other investment added', data: serialize_service(service) }, status: :created
    else
      render json: { success: false, message: 'Failed to add investment', errors: service.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/mobile/investments/other/:id
  def show_other
    render json: { success: true, data: serialize_service(@other) }
  end

  # PATCH /api/v1/mobile/investments/other/:id
  def update_other
    update_service(@other)
  end

  # DELETE /api/v1/mobile/investments/other/:id
  def destroy_other
    @other.destroy
    render json: { success: true, message: 'Investment removed' }
  end

  private

  # ── Finders ────────────────────────────────────────────────────────────────

  def set_mutual_fund
    @mutual_fund = MutualFund.find_by(id: params[:id], customer_id: current_customer.id)
    render json: { success: false, message: 'Mutual fund not found' }, status: :not_found unless @mutual_fund
  end

  def set_fd
    @fd = customer_services('investments_fd').find_by(id: params[:id])
    render json: { success: false, message: 'Fixed deposit not found' }, status: :not_found unless @fd
  end

  def set_other
    @other = customer_services('investments_other').find_by(id: params[:id])
    render json: { success: false, message: 'Investment not found' }, status: :not_found unless @other
  end

  # ── Shared helpers ─────────────────────────────────────────────────────────

  def customer_services(type)
    ClientService.where(customer_id: current_customer.id, service_type: type)
  end

  def update_service(record)
    attrs = slice_present(
      amount:           params[:amount],
      status:           params[:status],
      reference_number: params[:reference_number],
      start_date:       parse_date(params[:start_date]),
      notes:            params[:notes]
    )

    if record.update(attrs)
      render json: { success: true, message: 'Updated successfully', data: serialize_service(record) }
    else
      render json: { success: false, message: 'Update failed', errors: record.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def parse_date(value)
    return nil if value.blank?
    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def slice_present(hash)
    hash.reject { |_, v| v.nil? }
  end

  def render_missing(field)
    render json: { success: false, message: "#{field} is required" }, status: :unprocessable_entity
  end

  # ── Serializers ────────────────────────────────────────────────────────────

  # drwise shown the same way as insurance: is_admin_added == true
  def serialize_mutual_fund(mf)
    {
      id:               mf.id,
      record_type:      'mutual_fund',
      investment_type:  mf.investment_type,
      amount:           mf.amount.to_f,
      amount_formatted: format_indian_amount(mf.amount),
      fund_name:        mf.fund_name,
      folio_number:     mf.folio_number,
      plan_name:        mf.plan_name,
      start_date:       mf.start_date&.strftime('%Y-%m-%d'),
      maturity_date:    mf.maturity_date&.strftime('%Y-%m-%d'),
      active:           mf.active,
      drwise:           mf.is_admin_added == true,
      dr_wise:          mf.is_admin_added == true,
      created_at:       mf.created_at&.strftime('%Y-%m-%d %H:%M:%S'),
      updated_at:       mf.updated_at&.strftime('%Y-%m-%d %H:%M:%S')
    }
  end

  def serialize_service(service)
    {
      id:               service.id,
      record_type:      service.service_type,
      type_label:       service.service_type_label,
      amount:           service.amount.to_f,
      amount_formatted: format_indian_amount(service.amount),
      status:           service.status,
      reference_number: service.reference_number,
      start_date:       service.start_date&.strftime('%Y-%m-%d'),
      notes:            service.notes,
      created_at:       service.created_at&.strftime('%Y-%m-%d %H:%M:%S'),
      updated_at:       service.updated_at&.strftime('%Y-%m-%d %H:%M:%S')
    }
  end
end
