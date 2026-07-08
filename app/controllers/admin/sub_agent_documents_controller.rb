class Admin::SubAgentDocumentsController < Admin::ApplicationController
  before_action :set_sub_agent
  before_action :set_sub_agent_document, only: [:show, :edit, :update, :destroy, :destroy_immediate]

  # DELETE /admin/sub_agents/:sub_agent_id/sub_agent_documents/:id
  def destroy
    @sub_agent_document.destroy
    redirect_to edit_admin_sub_agent_path(@sub_agent), notice: 'Document was successfully deleted.'
  end

  # DELETE /admin/sub_agents/:sub_agent_id/sub_agent_documents/:id/destroy_immediate
  def destroy_immediate
    if @sub_agent_document.destroy
      render json: { success: true, message: 'Document was successfully deleted.' }
    else
      render json: { success: false, message: 'Failed to delete document.' }, status: :unprocessable_entity
    end
  end

  # POST /admin/sub_agents/:sub_agent_id/sub_agent_documents
  def create
    @sub_agent_document = @sub_agent.sub_agent_documents.build(sub_agent_document_params)

    # Handle R2 upload for Profile Images
    if params[:sub_agent_document][:document_file].present? && @sub_agent_document.document_type == 'Profile Image'
      file = params[:sub_agent_document][:document_file]

      if @sub_agent_document.upload_to_r2(file)
        respond_to do |format|
          format.html { redirect_to edit_admin_sub_agent_path(@sub_agent), notice: 'Profile image was successfully uploaded to cloud storage.' }
          format.json { render json: { success: true, message: 'Profile image uploaded successfully!' } }
        end
      else
        respond_to do |format|
          format.html { redirect_to edit_admin_sub_agent_path(@sub_agent), alert: 'Failed to upload profile image to cloud storage.' }
          format.json { render json: { success: false, message: 'Failed to upload profile image to cloud storage.' }, status: :unprocessable_entity }
        end
      end
    else
      # Regular ActiveStorage upload for other document types
      if @sub_agent_document.save
        respond_to do |format|
          format.html { redirect_to edit_admin_sub_agent_path(@sub_agent), notice: 'Document was successfully uploaded.' }
          format.json { render json: { success: true, message: 'Document uploaded successfully!' } }
        end
      else
        respond_to do |format|
          format.html { redirect_to edit_admin_sub_agent_path(@sub_agent), alert: 'Failed to upload document.' }
          format.json { render json: { success: false, message: @sub_agent_document.errors.full_messages.join(', ') }, status: :unprocessable_entity }
        end
      end
    end
  end

  # PATCH/PUT /admin/sub_agents/:sub_agent_id/sub_agent_documents/:id
  def update
    if @sub_agent_document.update(sub_agent_document_params)
      redirect_to edit_admin_sub_agent_path(@sub_agent), notice: 'Document was successfully updated.'
    else
      redirect_to edit_admin_sub_agent_path(@sub_agent), alert: 'Failed to update document.'
    end
  end

  # GET /admin/sub_agents/:sub_agent_id/sub_agent_documents/new
  def new
    @sub_agent_document = @sub_agent.sub_agent_documents.build
  end

  # GET /admin/sub_agents/:sub_agent_id/sub_agent_documents/:id/edit
  def edit
  end

  private

  def set_sub_agent
    @sub_agent = SubAgent.find(params[:sub_agent_id])
  end

  def set_sub_agent_document
    @sub_agent_document = @sub_agent.sub_agent_documents.find(params[:id])
  end

  def sub_agent_document_params
    params.require(:sub_agent_document).permit(:document_type, :document_file)
  end
end