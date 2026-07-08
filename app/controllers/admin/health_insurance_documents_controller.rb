class Admin::HealthInsuranceDocumentsController < Admin::ApplicationController
  before_action :set_health_insurance_document, only: [:destroy, :download]

  # GET /admin/health_insurance_documents/:id/download
  def download
    if @health_insurance_document.r2_file_key.present?
      redirect_to @health_insurance_document.document_url, allow_other_host: true
    else
      redirect_to admin_health_insurance_path(@health_insurance_document.health_insurance),
                  alert: 'Document not found'
    end
  end

  # DELETE /admin/health_insurance_documents/:id
  def destroy
    begin
      # Delete from R2 if file exists
      if @health_insurance_document.r2_file_key.present?
        R2Service.delete_file(@health_insurance_document.r2_file_key) rescue Rails.logger.warn("Failed to delete R2 file: #{@health_insurance_document.r2_file_key}")
      end

      # Delete the database record
      @health_insurance_document.destroy!

      respond_to do |format|
        format.json { render json: { success: true, message: 'Document deleted successfully' } }
        format.html {
          redirect_to edit_admin_health_insurance_path(@health_insurance_document.health_insurance),
                      notice: 'Document deleted successfully'
        }
      end

    rescue => e
      Rails.logger.error "Failed to delete health insurance document #{@health_insurance_document.id}: #{e.message}"

      respond_to do |format|
        format.json { render json: { success: false, message: "Failed to delete document: #{e.message}" }, status: :unprocessable_entity }
        format.html {
          redirect_to edit_admin_health_insurance_path(@health_insurance_document.health_insurance),
                      alert: "Failed to delete document: #{e.message}"
        }
      end
    end
  end

  private

  def set_health_insurance_document
    @health_insurance_document = HealthInsuranceDocument.find(params[:id])
  end
end