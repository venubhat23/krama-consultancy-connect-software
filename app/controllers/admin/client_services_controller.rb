class Admin::ClientServicesController < Admin::ApplicationController
  include ConfigurablePagination
  before_action :set_client_service, only: [:show, :edit, :update, :destroy]

  def index
    @service_type     = params[:service_type]
    @service_category = params[:service_category]
    @current_tab      = params[:tab].presence || 'drwise'

    @client_services = ClientService.includes(:customer, :sub_agent)

    if @service_type.present?
      @client_services = @client_services.by_type(@service_type)
      @page_title = ClientService::SERVICE_TYPES[@service_type] || @service_type.humanize
      @service_category = @service_type.split('_').first == 'credit' ? 'credit_card' :
        ClientService::TYPES_BY_CATEGORY.find { |_, types| types.include?(@service_type) }&.first
    elsif @service_category.present?
      @client_services = @client_services.by_category(@service_category)
      @page_title = ClientService::CATEGORY_LABELS[@service_category] || @service_category.humanize
    else
      @page_title = 'All Services'
    end

    # DrWise / Non-DrWise tab filter
    case @current_tab
    when 'drwise'
      @client_services = @client_services.where(is_admin_added: true)
    when 'non_drwise'
      @client_services = @client_services.where(is_admin_added: false)
    end

    if params[:search].present?
      term = "%#{params[:search]}%"
      @client_services = @client_services.joins(:customer).where(
        'client_services.reference_number ILIKE ? OR customers.first_name ILIKE ? OR customers.last_name ILIKE ? OR customers.company_name ILIKE ?',
        term, term, term, term
      )
    end

    if params[:status].present?
      @client_services = @client_services.where(status: params[:status])
    end

    calculate_statistics
    @client_services = paginate_records(@client_services.order(created_at: :desc))
  end

  def show
  end

  def new
    @client_service = ClientService.new(
      service_type: params[:service_type],
      status: 'pending'
    )
    @client_service.send(:set_category_from_type)
    set_form_data

    if params[:customer_id].present?
      @selected_customer = Customer.find_by(id: params[:customer_id])
      if @selected_customer
        @client_service.customer_id = @selected_customer.id
        if @selected_customer.affiliate.present?
          @client_service.sub_agent_id = @selected_customer.affiliate.id
          @auto_select_affiliate = @selected_customer.affiliate.id
        else
          @auto_select_affiliate = 'self'
        end
      end
    end
  end

  def edit
    set_form_data
    @selected_customer = @client_service.customer
    @auto_select_affiliate = @client_service.sub_agent_id.present? ? @client_service.sub_agent_id : 'self'
  end

  def create
    @client_service = ClientService.new(client_service_params)
    @client_service.is_admin_added = true
    set_distributor_from_affiliate(@client_service)

    if @client_service.save
      redirect_to admin_client_services_path(service_type: @client_service.service_type),
                  notice: "#{@client_service.service_type_label} record created successfully."
    else
      set_form_data
      @auto_select_affiliate = @client_service.sub_agent_id.present? ? @client_service.sub_agent_id : 'self'
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @client_service.assign_attributes(client_service_params)
    set_distributor_from_affiliate(@client_service)

    if @client_service.save
      redirect_to admin_client_services_path(service_type: @client_service.service_type),
                  notice: "#{@client_service.service_type_label} record updated successfully."
    else
      set_form_data
      @auto_select_affiliate = @client_service.sub_agent_id.present? ? @client_service.sub_agent_id : 'self'
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @client_service.destroy
    redirect_to admin_client_services_path(service_type: @client_service.service_type),
                notice: 'Record deleted successfully.'
  end

  private

  def set_client_service
    @client_service = ClientService.find(params[:id])
  end

  def set_form_data
    @customers   = Customer.active.order(:first_name, :last_name, :company_name)
    @sub_agents  = SubAgent.active.order(:first_name, :last_name)
    @distributors = Distributor.active.order(:first_name, :last_name)
  end

  def set_distributor_from_affiliate(record)
    return if record.sub_agent_id.blank?
    sub_agent = SubAgent.find_by(id: record.sub_agent_id)
    return unless sub_agent
    distributor_id = sub_agent.distributor_id || sub_agent.assigned_distributor&.id
    record.distributor_id = distributor_id.present? ? distributor_id : Distributor.active.first&.id
  rescue StandardError => e
    Rails.logger.error "Failed to set distributor: #{e.message}"
  end

  def calculate_statistics
    scope = @service_type.present? ? ClientService.by_type(@service_type) :
            (@service_category.present? ? ClientService.by_category(@service_category) : ClientService)
    @drwise_count     = scope.where(is_admin_added: true).count
    @non_drwise_count = scope.where(is_admin_added: false).count
    @total_count      = @drwise_count + @non_drwise_count
    @pending_count    = scope.where(status: 'pending').count
    @completed_count  = scope.where(status: 'completed').count
    @drwise_amount    = scope.where(is_admin_added: true).sum(:amount)
    @non_drwise_amount = scope.where(is_admin_added: false).sum(:amount)
    @total_amount     = @drwise_amount + @non_drwise_amount
  end

  def client_service_params
    params.require(:client_service).permit(
      :service_type, :service_category, :customer_id, :sub_agent_id, :distributor_id,
      :amount, :status, :reference_number, :start_date, :notes,
      :is_admin_added, :is_customer_added, :is_agent_added,
      :main_agent_commission_percentage, :commission_amount, :tds_percentage, :tds_amount, :after_tds_value,
      :sub_agent_commission_percentage, :sub_agent_commission_amount, :sub_agent_tds_percentage, :sub_agent_tds_amount, :sub_agent_after_tds_value,
      :distributor_commission_percentage, :distributor_commission_amount, :distributor_tds_percentage, :distributor_tds_amount, :distributor_after_tds_value,
      :investor_commission_percentage, :investor_commission_amount,
      :company_expenses_percentage, :company_expenses_amount,
      :total_distribution_percentage, :profit_percentage, :profit_amount
    )
  end
end
