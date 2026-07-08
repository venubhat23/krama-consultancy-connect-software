class Admin::DistributorDocumentsController < Admin::ApplicationController
  before_action :set_distributor
  before_action :set_distributor_document, only: [:show, :edit, :update, :destroy, :destroy_immediate]

  # DELETE /admin/distributors/:distributor_id/distributor_documents/:id
  def destroy
    @distributor_document.destroy
    redirect_to edit_admin_distributor_path(@distributor), notice: 'Document was successfully deleted.'
  end

  # DELETE /admin/distributors/:distributor_id/distributor_documents/:id/destroy_immediate
  def destroy_immediate
    if @distributor_document.destroy
      render json: { success: true, message: 'Document was successfully deleted.' }
    else
      render json: { success: false, message: 'Failed to delete document.' }, status: :unprocessable_entity
    end
  end

  # POST /admin/distributors/:distributor_id/distributor_documents
  def create
    @distributor_document = @distributor.distributor_documents.build(distributor_document_params)

    if @distributor_document.save
      redirect_to edit_admin_distributor_path(@distributor), notice: 'Document was successfully uploaded.'
    else
      redirect_to edit_admin_distributor_path(@distributor), alert: 'Failed to upload document.'
    end
  end

  # PATCH/PUT /admin/distributors/:distributor_id/distributor_documents/:id
  def update
    if @distributor_document.update(distributor_document_params)
      redirect_to edit_admin_distributor_path(@distributor), notice: 'Document was successfully updated.'
    else
      redirect_to edit_admin_distributor_path(@distributor), alert: 'Failed to update document.'
    end
  end

  # GET /admin/distributors/:distributor_id/distributor_documents/new
  def new
    @distributor_document = @distributor.distributor_documents.build
  end

  # GET /admin/distributors/:distributor_id/distributor_documents/:id/edit
  def edit
  end

  private

  def set_distributor
    @distributor = Distributor.find(params[:distributor_id])
  end

  def set_distributor_document
    @distributor_document = @distributor.distributor_documents.find(params[:id])
  end

  def distributor_document_params
    params.require(:distributor_document).permit(:document_type, :document_file)
  end
end