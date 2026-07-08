module MobileClientServiceCrud
  extend ActiveSupport::Concern

  private

  # List all records of a given service_type for the current customer
  def list_service(service_type)
    scope = customer_scope(service_type).order(created_at: :desc)
    scope = scope.where(status: params[:status]) if params[:status].present?

    render json: {
      success: true,
      data: {
        records:      scope.map { |s| serialize_cs(s) },
        total:        scope.count,
        total_amount: format_indian_amount(scope.sum(:amount))
      }
    }
  end

  # Create a new record.
  # Pass drwise: true in the request body to mark this as a DrWise-managed record.
  def create_service(service_type)
    return render_missing('amount') if params[:amount].blank?

    drwise = params[:drwise].to_s == 'true'

    service = ClientService.new(
      customer_id:       current_customer.id,
      service_type:      service_type,
      amount:            params[:amount],
      status:            params[:status].presence || 'pending',
      reference_number:  params[:reference_number],
      start_date:        parse_date(params[:start_date]),
      notes:             params[:notes],
      is_admin_added:    drwise,
      is_customer_added: !drwise,
      is_agent_added:    false
    )

    if service.save
      render json: { success: true, message: 'Record created successfully', data: serialize_cs(service) }, status: :created
    else
      render json: { success: false, message: 'Failed to create record', errors: service.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def show_service(record)
    render json: { success: true, data: serialize_cs(record) }
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
      render json: { success: true, message: 'Updated successfully', data: serialize_cs(record) }
    else
      render json: { success: false, message: 'Update failed', errors: record.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy_service(record)
    record.destroy
    render json: { success: true, message: 'Record removed' }
  end

  # Scoped finder — ensures customer can only access their own records
  def find_cs!(service_type)
    record = customer_scope(service_type).find_by(id: params[:id])
    render json: { success: false, message: 'Record not found' }, status: :not_found unless record
    record
  end

  def customer_scope(service_type)
    ClientService.where(customer_id: current_customer.id, service_type: service_type)
  end

  # Summary across multiple service_types
  def build_category_summary(*types)
    total_amount = types.sum { |t| customer_scope(t).sum(:amount).to_f }

    {
      total:            types.sum { |t| customer_scope(t).count },
      total_amount:     format_indian_amount(total_amount),
      total_amount_raw: total_amount,
      by_type:          types.each_with_object({}) do |t, h|
        scope = customer_scope(t)
        amt   = scope.sum(:amount).to_f
        h[t]  = {
          label:        ClientService::SERVICE_TYPES[t],
          count:        scope.count,
          total_amount: format_indian_amount(amt),
          total_amount_raw: amt
        }
      end
    }
  end

  def serialize_cs(service)
    {
      id:               service.id,
      record_type:      service.service_type,
      type_label:       service.service_type_label,
      category:         service.service_category,
      amount:           service.amount.to_f,
      amount_formatted: format_indian_amount(service.amount),
      status:           service.status,
      reference_number: service.reference_number,
      start_date:       service.start_date&.strftime('%Y-%m-%d'),
      notes:            service.notes,
      drwise:           service.is_admin_added == true,
      dr_wise:          service.is_admin_added == true,
      created_at:       service.created_at&.strftime('%Y-%m-%d %H:%M:%S'),
      updated_at:       service.updated_at&.strftime('%Y-%m-%d %H:%M:%S')
    }
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
end
