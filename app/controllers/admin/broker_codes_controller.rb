class Admin::BrokerCodesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_broker_code, only: [:show, :edit, :update, :destroy, :toggle_status]
  before_action :set_broker, only: [:index, :new, :create], if: :broker_context?

  def index
    @broker_codes = if @broker
                      @broker.broker_codes.includes(:broker)
                    else
                      BrokerCode.includes(:broker).all
                    end

    # Apply search if present
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @broker_codes = @broker_codes.joins(:broker).where(
        "broker_code ILIKE ? OR company_name ILIKE ? OR brokers.name ILIKE ?",
        search_term, search_term, search_term
      )
    end

    # Apply status filter
    if params[:status].present? && params[:status] != 'all'
      @broker_codes = @broker_codes.where(status: params[:status] == 'active')
    end

    @broker_codes = @broker_codes.joins(:broker).order('brokers.name')

    # Handle different response formats
    respond_to do |format|
      format.html do
        # Get all brokers and companies for dropdowns
        @brokers = Broker.active.order(:name)
        @companies = InsuranceCompany.order(:name).pluck(:name)
      end

      format.json do
        # For JSON requests, return all active broker codes with broker names
        render json: {
          success: true,
          broker_codes: @broker_codes.where(status: true).map do |broker_code|
            {
              id: broker_code.id,
              broker_id: broker_code.broker_id,
              broker_name: broker_code.broker.name,
              broker_code: broker_code.broker_code,
              company_name: broker_code.company_name,
              display_name: "#{broker_code.broker.name} (#{broker_code.broker_code})"
            }
          end
        }
      end
    end
  end

  def new
    @broker_code = @broker ? @broker.broker_codes.build : BrokerCode.new
    @brokers = Broker.active.order(:name)
    @companies = InsuranceCompany.order(:name).pluck(:name)
  end

  def create
    @broker_code = @broker ? @broker.broker_codes.build(broker_code_params) : BrokerCode.new(broker_code_params)

    if @broker_code.save
      # Always redirect to brokers page with #broker-code anchor after successful creation
      redirect_to admin_brokers_path(anchor: 'broker-code'), notice: "Broker code created successfully!"
    else
      @brokers = Broker.active.order(:name)
      @companies = InsuranceCompany.order(:name).pluck(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @brokers = Broker.active.order(:name)
    @companies = InsuranceCompany.order(:name).pluck(:name)
  end

  def update
    if @broker_code.update(broker_code_params)
      # Redirect to brokers page with #broker-code anchor after successful update
      redirect_to admin_brokers_path(anchor: 'broker-code'), notice: "Broker code updated successfully!"
    else
      @brokers = Broker.active.order(:name)
      @companies = InsuranceCompany.order(:name).pluck(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @broker_code.destroy
    # Redirect to brokers page with #broker-code anchor after successful deletion
    redirect_to admin_brokers_path(anchor: 'broker-code'), notice: "Broker code deleted successfully!"
  end

  def toggle_status
    @broker_code.update(status: !@broker_code.status)
    status_text = @broker_code.status? ? 'activated' : 'deactivated'
    # Redirect to brokers page with #broker-code anchor after status toggle
    redirect_to admin_brokers_path(anchor: 'broker-code'), notice: "Broker code #{status_text} successfully!"
  end


  private

  def set_broker_code
    @broker_code = BrokerCode.find(params[:id])
  end

  def set_broker
    @broker = Broker.find(params[:broker_id]) if params[:broker_id].present?
  end

  def broker_context?
    params[:broker_id].present?
  end

  def broker_code_params
    params.require(:broker_code).permit(:broker_id, :broker_code, :agent_name, :company_name, :status)
  end

end