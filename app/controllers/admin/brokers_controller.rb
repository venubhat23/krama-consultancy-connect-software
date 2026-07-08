class Admin::BrokersController < Admin::ApplicationController
  include InsuranceCompanyMethods
  before_action :set_broker, only: [:show, :edit, :update, :destroy, :toggle_status]

  def index
    @brokers = Broker.includes(:insurance_company)
    @brokers = @brokers.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?

    respond_to do |format|
      format.html do
        # Get total count before pagination for display purposes
        @total_filtered_count = @brokers.count

        # Apply pagination (10 records per page)
        @brokers = @brokers.order(:name).page(params[:page]).per(10)

        @broker = Broker.new

        # Statistics for dashboard cards (use unfiltered counts)
        @total_brokers = Broker.count
        @active_brokers = Broker.active.count
        @inactive_brokers = Broker.inactive.count

        # Data for Broker Code tab (using new BrokerCode model)
        @broker_codes = BrokerCode.includes(:broker)

        # Apply search filter to broker codes if present
        if params[:search].present?
          search_term = "%#{params[:search]}%"
          @broker_codes = @broker_codes.joins(:broker).where(
            "broker_codes.broker_code ILIKE ? OR brokers.name ILIKE ?",
            search_term, search_term
          )
        end

        # Get total count before pagination for display purposes
        @total_filtered_broker_codes = @broker_codes.count

        # Apply pagination for broker codes (10 records per page)
        @broker_codes = @broker_codes.order(created_at: :desc).page(params[:page]).per(10)

        # Determine which tab should be active
        # Check for anchor parameter or tab parameter
        if params[:anchor] == 'broker-code' || request.fullpath.include?('#broker-code')
          @active_tab = 'broker-code'
        else
          @active_tab = params[:tab] || 'broker-list'
        end
      end

      format.json do
        # For JSON requests, return all matching records without pagination
        @brokers = @brokers.order(:name)
        render json: @brokers.map do |broker|
          {
            id: broker.id,
            name: broker.name,
            status: broker.status,
            insurance_company_id: broker.insurance_company_id
          }
        end
      end
    end
  end

  def show
  end

  def new
    @broker = Broker.new
  end

  def create
    @broker = Broker.new(broker_params)
    @broker.status = 'active' # Default status

    if @broker.save
      redirect_to admin_brokers_path, notice: 'Broker was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @broker.update(broker_params)
      redirect_to admin_brokers_path, notice: 'Broker was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # Check if broker has dependent records Dr WISE all insurance types
    dependent_records = []

    life_count = @broker.life_insurances.count
    dependent_records << "#{life_count} life insurance #{'policy'.pluralize(life_count)}" if life_count > 0

    health_count = @broker.health_insurances.count
    dependent_records << "#{health_count} health insurance #{'policy'.pluralize(health_count)}" if health_count > 0

    motor_count = @broker.respond_to?(:motor_insurances) ? @broker.motor_insurances.count : 0
    dependent_records << "#{motor_count} motor insurance #{'policy'.pluralize(motor_count)}" if motor_count > 0

    if dependent_records.any?
      policy_list = dependent_records.join(', ')

      # Get specific policy details for the user
      policy_details = []

      if life_count > 0
        life_policies = @broker.life_insurances.limit(3).pluck(:policy_number, :id)
        life_policies.each { |policy_number, id| policy_details << "Life Policy ##{policy_number} (ID: #{id})" }
        policy_details << "...and #{life_count - 3} more life policies" if life_count > 3
      end

      if health_count > 0
        health_policies = @broker.health_insurances.limit(3).pluck(:policy_number, :id)
        health_policies.each { |policy_number, id| policy_details << "Health Policy ##{policy_number} (ID: #{id})" }
        policy_details << "...and #{health_count - 3} more health policies" if health_count > 3
      end

      if motor_count > 0
        motor_policies = @broker.motor_insurances.limit(3).pluck(:policy_number, :id)
        motor_policies.each { |policy_number, id| policy_details << "Motor Policy ##{policy_number} (ID: #{id})" }
        policy_details << "...and #{motor_count - 3} more motor policies" if motor_count > 3
      end

      details = policy_details.any? ? " Affected policies: #{policy_details.join(', ')}" : ""

      redirect_to admin_brokers_path,
                  alert: "Cannot delete broker '#{@broker.name}' because it is referenced by #{policy_list}.#{details} Please reassign or remove these policies first."
      return
    end

    if @broker.destroy
      redirect_to admin_brokers_path, notice: 'Broker was successfully deleted.'
    else
      redirect_to admin_brokers_path, alert: 'Failed to delete broker.'
    end
  rescue ActiveRecord::InvalidForeignKey => e
    redirect_to admin_brokers_path,
                alert: "Cannot delete broker '#{@broker.name}' because it is still referenced by other records. Please remove dependencies first."
  end

  def toggle_status
    @broker.update(status: @broker.active? ? 'inactive' : 'active')
    redirect_to admin_brokers_path, notice: 'Broker status was successfully updated.'
  end

  # GET /admin/brokers/search - For AJAX search
  def search
    @brokers = Broker.includes(:insurance_company)
    @brokers = @brokers.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?

    # Get total count before pagination for display purposes
    @total_filtered_count = @brokers.count

    # Apply pagination (10 records per page)
    @brokers = @brokers.order(:name).page(params[:page]).per(10)

    render partial: 'brokers_table', locals: { brokers: @brokers, total_filtered_count: @total_filtered_count }
  end

  private

  def set_broker
    @broker = Broker.find(params[:id])
  end

  def broker_params
    params.require(:broker).permit(:name)
  end
end