class Api::V1::Mobile::ClientServicesController < Api::V1::Mobile::BaseController
  before_action :authenticate_agent!
  before_action :set_service, only: [:show, :update, :destroy]

  CATEGORY_MAP = {
    'investments'  => %w[investments_mutual_fund investments_fd investments_other],
    'taxation'     => %w[taxation_itr taxation_tax_planning],
    'loans'        => %w[loans_personal loans_home loans_mortgage loans_business],
    'travel'       => %w[travel_domestic travel_international],
    'credit_card'  => %w[credit_card_rewards credit_card_business credit_card_travel]
  }.freeze

  # GET /api/v1/mobile/client_services
  # Optional params: category, service_type, customer_id, status, page, per_page
  def index
    services = base_scope

    services = services.by_category(params[:category]) if params[:category].present?
    services = services.by_type(params[:service_type]) if params[:service_type].present?
    services = services.where(status: params[:status]) if params[:status].present?

    if params[:customer_id].present?
      services = services.where(customer_id: params[:customer_id])
    end

    page     = (params[:page]     || 1).to_i
    per_page = (params[:per_page] || 20).to_i
    services = services.order(created_at: :desc).page(page).per(per_page)

    render_success(
      {
        services: services.map { |s| serialize_service(s) },
        pagination: {
          current_page: page,
          per_page: per_page,
          total_count: services.total_count,
          total_pages: services.total_pages
        },
        available_categories: ClientService::CATEGORY_LABELS,
        available_types: ClientService::SERVICE_TYPES
      }
    )
  end

  # GET /api/v1/mobile/client_services/:id
  def show
    render_success(serialize_service(@service))
  end

  # POST /api/v1/mobile/client_services
  def create
    errors = validate_create_params
    return render_error('Validation failed', :unprocessable_entity, errors) if errors.any?

    customer = Customer.find_by(id: params[:customer_id])
    return render_error('Customer not found', :not_found) unless customer

    sub_agent_id = resolve_sub_agent_id

    service = ClientService.new(
      customer: customer,
      sub_agent_id: sub_agent_id,
      service_type: params[:service_type],
      amount: params[:amount] || 0,
      status: params[:status] || 'pending',
      reference_number: params[:reference_number],
      start_date: parse_date(params[:start_date]),
      notes: params[:notes],
      main_agent_commission_percentage: params[:main_agent_commission_percentage] || 0,
      commission_amount: params[:commission_amount] || 0,
      tds_percentage: params[:tds_percentage] || 0
    )

    if service.save
      render_success(serialize_service(service), 'Service created successfully')
    else
      render_error('Failed to create service', :unprocessable_entity, service.errors.full_messages)
    end
  end

  # PATCH /api/v1/mobile/client_services/:id
  def update
    allowed = params.permit(:status, :notes, :amount, :reference_number, :start_date,
                            :main_agent_commission_percentage, :commission_amount)
    allowed[:start_date] = parse_date(allowed[:start_date]) if allowed[:start_date].present?

    if @service.update(allowed)
      render_success(serialize_service(@service), 'Service updated successfully')
    else
      render_error('Failed to update service', :unprocessable_entity, @service.errors.full_messages)
    end
  end

  # DELETE /api/v1/mobile/client_services/:id
  def destroy
    @service.destroy
    render_success(nil, 'Service deleted successfully')
  end

  # GET /api/v1/mobile/client_services/investments
  def investments
    list_by_category('investments')
  end

  # GET /api/v1/mobile/client_services/taxation
  def taxation
    list_by_category('taxation')
  end

  # GET /api/v1/mobile/client_services/loans
  def loans
    list_by_category('loans')
  end

  # GET /api/v1/mobile/client_services/travel
  def travel
    list_by_category('travel')
  end

  # GET /api/v1/mobile/client_services/credit_card
  def credit_card
    list_by_category('credit_card')
  end

  # GET /api/v1/mobile/client_services/form_data
  def form_data
    render_success(
      {
        categories: ClientService::CATEGORY_LABELS.map { |k, v| { value: k, label: v } },
        service_types: ClientService::SERVICE_TYPES.map { |k, v| { value: k, label: v } },
        types_by_category: ClientService::TYPES_BY_CATEGORY.transform_values do |types|
          types.map { |t| { value: t, label: ClientService::SERVICE_TYPES[t] } }
        end,
        statuses: ClientService::STATUSES.map { |s| { value: s, label: s.humanize } },
        payment_modes: %w[monthly quarterly half_yearly yearly one_time],
        loan_types: %w[loans_personal loans_home loans_mortgage loans_business].map do |t|
          { value: t, label: ClientService::SERVICE_TYPES[t] }
        end,
        investment_types: %w[investments_mutual_fund investments_fd investments_other].map do |t|
          { value: t, label: ClientService::SERVICE_TYPES[t] }
        end,
        taxation_types: %w[taxation_itr taxation_tax_planning].map do |t|
          { value: t, label: ClientService::SERVICE_TYPES[t] }
        end,
        travel_types: %w[travel_domestic travel_international].map do |t|
          { value: t, label: ClientService::SERVICE_TYPES[t] }
        end,
        credit_card_types: %w[credit_card_rewards credit_card_business credit_card_travel].map do |t|
          { value: t, label: ClientService::SERVICE_TYPES[t] }
        end
      }
    )
  end

  # GET /api/v1/mobile/client_services/summary
  def summary
    services = base_scope

    by_category = ClientService::CATEGORY_LABELS.keys.each_with_object({}) do |cat, h|
      cat_services = services.by_category(cat)
      h[cat] = {
        label: ClientService::CATEGORY_LABELS[cat],
        total: cat_services.count,
        total_amount: cat_services.sum(:amount).to_f.round(2),
        pending: cat_services.where(status: 'pending').count,
        in_progress: cat_services.where(status: 'in_progress').count,
        completed: cat_services.where(status: 'completed').count,
        cancelled: cat_services.where(status: 'cancelled').count
      }
    end

    render_success(
      {
        total_services: services.count,
        total_amount: services.sum(:amount).to_f.round(2),
        by_category: by_category
      }
    )
  end

  private

  def authenticate_agent!
    token = request.headers['Authorization']&.split(' ')&.last
    return render_error('Authorization token is required', :unauthorized) if token.blank?

    begin
      decoded = JWT.decode(token, Rails.application.secret_key_base)[0]
      role = decoded['role']
      user_id = decoded['user_id']

      @current_user = case role
                      when 'agent'     then User.find(user_id)
                      when 'sub_agent' then SubAgent.find(user_id)
                      else return render_error('Agent authorization required', :unauthorized)
                      end
    rescue JWT::DecodeError
      render_error('Invalid authorization token', :unauthorized)
    rescue ActiveRecord::RecordNotFound
      render_error('Agent not found', :unauthorized)
    end
  end

  def set_service
    @service = base_scope.find_by(id: params[:id])
    render_error('Service not found', :not_found) unless @service
  end

  def base_scope
    if @current_user.is_a?(SubAgent)
      ClientService.where(sub_agent_id: @current_user.id)
    elsif @current_user.is_a?(User) && admin_user?
      ClientService.all
    else
      sub_agent = SubAgent.find_by(email: @current_user.email)
      sub_agent ? ClientService.where(sub_agent_id: sub_agent.id) : ClientService.none
    end
  end

  def admin_user?
    @current_user.is_a?(User) && @current_user.respond_to?(:role) &&
      %w[admin super_admin].include?(@current_user.role&.name&.downcase)
  end

  def resolve_sub_agent_id
    if @current_user.is_a?(SubAgent)
      @current_user.id
    elsif @current_user.is_a?(User)
      SubAgent.find_by(email: @current_user.email)&.id
    end
  end

  def list_by_category(category)
    page     = (params[:page]     || 1).to_i
    per_page = (params[:per_page] || 20).to_i

    services = base_scope.by_category(category)
    services = services.where(customer_id: params[:customer_id]) if params[:customer_id].present?
    services = services.where(status: params[:status]) if params[:status].present?
    services = services.where(service_type: params[:service_type]) if params[:service_type].present?
    services = services.order(created_at: :desc).page(page).per(per_page)

    render_success(
      {
        category: category,
        category_label: ClientService::CATEGORY_LABELS[category],
        service_types: CATEGORY_MAP[category].map { |t| { value: t, label: ClientService::SERVICE_TYPES[t] } },
        services: services.map { |s| serialize_service(s) },
        pagination: {
          current_page: page,
          per_page: per_page,
          total_count: services.total_count,
          total_pages: services.total_pages
        }
      }
    )
  end

  def validate_create_params
    errors = []
    errors << 'customer_id is required' if params[:customer_id].blank?
    errors << 'service_type is required' if params[:service_type].blank?

    if params[:service_type].present? && !ClientService::SERVICE_TYPES.key?(params[:service_type])
      errors << "Invalid service_type. Valid values: #{ClientService::SERVICE_TYPES.keys.join(', ')}"
    end

    errors
  end

  def serialize_service(service)
    {
      id: service.id,
      service_type: service.service_type,
      service_type_label: service.service_type_label,
      service_category: service.service_category,
      category_label: service.category_label,
      customer_id: service.customer_id,
      customer_name: service.customer&.display_name,
      sub_agent_id: service.sub_agent_id,
      amount: service.amount.to_f,
      status: service.status,
      status_badge_class: service.status_badge_class,
      reference_number: service.reference_number,
      start_date: service.start_date&.strftime('%Y-%m-%d'),
      notes: service.notes,
      commission: {
        main_agent_percentage: service.main_agent_commission_percentage.to_f,
        commission_amount: service.commission_amount.to_f,
        tds_percentage: service.tds_percentage.to_f,
        tds_amount: service.tds_amount.to_f,
        after_tds_value: service.after_tds_value.to_f,
        sub_agent_percentage: service.sub_agent_commission_percentage.to_f,
        sub_agent_amount: service.sub_agent_commission_amount.to_f,
        sub_agent_after_tds: service.sub_agent_after_tds_value.to_f
      },
      created_at: service.created_at.strftime('%Y-%m-%d %H:%M:%S'),
      updated_at: service.updated_at.strftime('%Y-%m-%d %H:%M:%S')
    }
  end

  def parse_date(value)
    return nil if value.blank?
    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end
end
