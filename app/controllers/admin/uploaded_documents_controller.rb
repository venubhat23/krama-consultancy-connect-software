class Admin::UploadedDocumentsController < Admin::ApplicationController
  before_action :set_customer
  before_action :set_document, only: [:show, :destroy]

  # DELETE /admin/customers/:customer_id/uploaded_documents/:id
  def destroy
    # Just unlink from customer - do NOT delete from R2 storage
    if @document.destroy
      if request.format.json?
        render json: {
          success: true,
          message: 'Document unlinked from customer successfully! File remains in cloud storage.'
        }
      else
        redirect_to edit_admin_customer_path(@customer),
                    notice: 'Document unlinked successfully! File remains in cloud storage.'
      end
    else
      if request.format.json?
        render json: {
          success: false,
          message: 'Failed to unlink document'
        }, status: :unprocessable_entity
      else
        redirect_to edit_admin_customer_path(@customer),
                    alert: 'Failed to unlink document.'
      end
    end
  end

  private

  def set_customer
    @customer = Customer.find(params[:customer_id])
  end

  def set_document
    @document = @customer.uploaded_documents.find(params[:id])
  end
end