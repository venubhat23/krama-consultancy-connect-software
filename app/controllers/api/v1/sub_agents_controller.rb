class Api::V1::SubAgentsController < Api::V1::ApplicationController

  # GET /api/v1/sub_agents
  def index
    sub_agents = SubAgent.all

    # Search functionality
    if params[:search].present?
      sub_agents = sub_agents.search_by_name_mobile_email(params[:search])
    end

    # Filter by status
    case params[:status]
    when 'active'
      sub_agents = sub_agents.active
    when 'inactive'
      sub_agents = sub_agents.inactive
    end

    sub_agents = sub_agents.order(created_at: :desc)

    # Pagination
    page = params[:page] || 1
    per_page = params[:per_page] || 20
    sub_agents = sub_agents.page(page).per(per_page)

    render_success({
      sub_agents: sub_agents.map { |sub_agent| sub_agent_response(sub_agent) },
      pagination: {
        current_page: sub_agents.current_page,
        total_pages: sub_agents.total_pages,
        total_count: sub_agents.total_count,
        per_page: sub_agents.limit_value
      },
      statistics: {
        total_sub_agents: SubAgent.count,
        active_sub_agents: SubAgent.active.count,
        inactive_sub_agents: SubAgent.inactive.count
      }
    })
  end

  # GET /api/v1/sub_agents/:id
  def show
    sub_agent = SubAgent.find(params[:id])
    documents = sub_agent.sub_agent_documents.map do |doc|
      {
        id: doc.id,
        document_type: doc.document_type,
        document_name: doc.document_name,
        document_url: doc.document_url,
        created_at: doc.created_at
      }
    end

    render_success({
      sub_agent: sub_agent_response(sub_agent),
      documents: documents
    })
  rescue ActiveRecord::RecordNotFound
    render_error('Sub Agent not found', nil, :not_found)
  end

  # POST /api/v1/sub_agents
  def create
    sub_agent = SubAgent.new(sub_agent_params)

    if sub_agent.save
      render_success(sub_agent_response(sub_agent), 'Sub Agent created successfully', :created)
    else
      render_validation_errors(sub_agent)
    end
  end

  # PUT /api/v1/sub_agents/:id
  def update
    sub_agent = SubAgent.find(params[:id])

    if sub_agent.update(sub_agent_params)
      render_success(sub_agent_response(sub_agent), 'Sub Agent updated successfully')
    else
      render_validation_errors(sub_agent)
    end
  rescue ActiveRecord::RecordNotFound
    render_error('Sub Agent not found', nil, :not_found)
  end

  # DELETE /api/v1/sub_agents/:id
  def destroy
    sub_agent = SubAgent.find(params[:id])
    sub_agent.destroy
    render_success(nil, 'Sub Agent deleted successfully')
  rescue ActiveRecord::RecordNotFound
    render_error('Sub Agent not found', nil, :not_found)
  end

  # PATCH /api/v1/sub_agents/:id/toggle_status
  def toggle_status
    sub_agent = SubAgent.find(params[:id])
    new_status = sub_agent.active? ? :inactive : :active

    if sub_agent.update(status: new_status)
      render_success(
        sub_agent_response(sub_agent),
        "Sub Agent status updated to #{new_status}"
      )
    else
      render_validation_errors(sub_agent)
    end
  rescue ActiveRecord::RecordNotFound
    render_error('Sub Agent not found', nil, :not_found)
  end

  private

  def sub_agent_params
    params.require(:sub_agent).permit(
      :first_name, :middle_name, :last_name, :mobile, :email, :role_id,
      :state_id, :city_id, :birth_date, :gender, :pan_no, :gst_no,
      :company_name, :address, :bank_name, :account_no, :ifsc_code,
      :account_holder_name, :account_type, :upi_id, :status, :upload_main_document,
      sub_agent_documents_attributes: [:id, :document_type, :document_file, :_destroy]
    )
  end

  def sub_agent_response(sub_agent)
    {
      id: sub_agent.id,
      first_name: sub_agent.first_name,
      middle_name: sub_agent.middle_name,
      last_name: sub_agent.last_name,
      full_name: sub_agent.full_name,
      display_name: sub_agent.display_name,
      mobile: sub_agent.mobile,
      email: sub_agent.email,
      role_id: sub_agent.role_id,
      state_id: sub_agent.state_id,
      city_id: sub_agent.city_id,
      birth_date: sub_agent.birth_date,
      gender: sub_agent.gender,
      pan_no: sub_agent.pan_no,
      gst_no: sub_agent.gst_no,
      company_name: sub_agent.company_name,
      address: sub_agent.address,
      bank_name: sub_agent.bank_name,
      account_no: sub_agent.account_no,
      ifsc_code: sub_agent.ifsc_code,
      account_holder_name: sub_agent.account_holder_name,
      account_type: sub_agent.account_type,
      upi_id: sub_agent.upi_id,
      status: sub_agent.status,
      upload_main_document_url: sub_agent.upload_main_document.attached? ? Rails.application.routes.url_helpers.rails_blob_path(sub_agent.upload_main_document, only_path: true) : nil,
      created_at: sub_agent.created_at,
      updated_at: sub_agent.updated_at
    }
  end
end