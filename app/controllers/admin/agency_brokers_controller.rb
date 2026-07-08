class Admin::AgencyBrokersController < Admin::ApplicationController
  # This is a placeholder controller for agency/broker management
  # In practice, this might be handled through the Users controller with specific user_types

  def index
    @agency_brokers = User.where(user_type: ['agent', 'sub_agent']).order(:first_name)
    @agency_brokers = @agency_brokers.page(params[:page])
  end

  def show
    @agency_broker = User.find(params[:id])
  end

  def new
    @agency_broker = User.new(user_type: 'agent')
  end

  def edit
    @agency_broker = User.find(params[:id])
  end

  def create
    @agency_broker = User.new(agency_broker_params)
    @agency_broker.user_type = 'agent'

    if @agency_broker.save
      redirect_to admin_agency_broker_path(@agency_broker), notice: 'Agency/Broker was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @agency_broker = User.find(params[:id])

    if @agency_broker.update(agency_broker_params)
      redirect_to admin_agency_broker_path(@agency_broker), notice: 'Agency/Broker was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @agency_broker = User.find(params[:id])
    @agency_broker.destroy
    redirect_to admin_agency_brokers_path, notice: 'Agency/Broker was successfully deleted.'
  end

  private

  def agency_broker_params
    params.require(:user).permit(
      :first_name, :last_name, :email, :mobile, :user_type, :role, :status,
      :address, :state, :city, :pan_number, :gst_number
    )
  end
end