class Admin::ClientRequestsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_client_request, only: [:show, :edit, :update, :destroy, :update_status, :assign_to, :add_response]

  def index
    @client_requests = ClientRequest.includes(:resolved_by).recent

    # Apply filters
    @client_requests = @client_requests.where(status: params[:status]) if params[:status].present?
    @client_requests = @client_requests.where(priority: params[:priority]) if params[:priority].present?

    # Apply search
    if params[:search].present?
      @client_requests = @client_requests.search_requests(params[:search])
    end

    @client_requests = @client_requests.page(params[:page]).per(20)

    # Statistics for dashboard cards
    @stats = {
      total: ClientRequest.count,
      pending: ClientRequest.pending.count,
      in_progress: ClientRequest.in_progress.count,
      resolved: ClientRequest.resolved.count,
      closed: ClientRequest.closed.count
    }
  end

  def show
  end

  def edit
  end

  def update
    if @client_request.update(client_request_params)
      redirect_to admin_client_request_path(@client_request), notice: 'Client request updated successfully.'
    else
      render :edit
    end
  end

  def destroy
    @client_request.destroy
    redirect_to admin_client_requests_path, notice: 'Client request deleted successfully.'
  end

  def pending
    @client_requests = ClientRequest.pending.recent.page(params[:page]).per(20)
    render :index
  end

  def in_progress
    @client_requests = ClientRequest.in_progress.recent.page(params[:page]).per(20)
    render :index
  end

  def resolved
    @client_requests = ClientRequest.resolved.recent.page(params[:page]).per(20)
    render :index
  end

  def search
    @client_requests = ClientRequest.search_requests(params[:q]).recent.page(params[:page]).per(20)
    render :index
  end

  def update_status
    if @client_request.update(status: params[:status])
      render json: { success: true, message: 'Status updated successfully' }
    else
      render json: { success: false, errors: @client_request.errors.full_messages }
    end
  end

  def assign_to
    user = User.find_by(id: params[:user_id])
    if user && @client_request.update(resolved_by: user)
      render json: { success: true, message: 'Request assigned successfully' }
    else
      render json: { success: false, message: 'Failed to assign request' }
    end
  end

  def add_response
    if @client_request.update(admin_response: params[:admin_response])
      render json: { success: true, message: 'Response added successfully' }
    else
      render json: { success: false, errors: @client_request.errors.full_messages }
    end
  end

  private

  def set_client_request
    @client_request = ClientRequest.find(params[:id])
  end

  def client_request_params
    params.require(:client_request).permit(:status, :priority, :admin_response, :resolved_by_id)
  end
end