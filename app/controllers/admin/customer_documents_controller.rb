class Admin::CustomerDocumentsController < Admin::ApplicationController
  before_action :set_customer
  before_action :set_document, only: [:show, :destroy]

  # GET /admin/customers/:customer_id/documents
  def index
    # Always redirect to the customer edit page since this route isn't meant to be accessed directly
    redirect_to edit_admin_customer_path(@customer)
  end

  # POST /admin/customers/:customer_id/documents
  def create
    @document = @customer.documents.build(document_type: document_params[:document_type])

    if @document.save
      # Handle file upload to R2
      if params[:customer_document][:document_file].present?
        result = @document.upload_to_r2(params[:customer_document][:document_file])

        if result.is_a?(Hash) && result[:success]
          respond_to do |format|
            format.json {
              render json: {
                success: true,
                message: 'Document uploaded successfully!',
                document: {
                  id: @document.id,
                  name: @document.document_name,
                  type: @document.document_type,
                  size: @document.document_size,
                  url: @document.document_url
                }
              }
            }
            format.html {
              redirect_to edit_admin_customer_path(@customer), notice: 'Document uploaded successfully!'
            }
          end
        else
          @document.destroy
          error_message = result.is_a?(Hash) ? result[:error] : 'Upload failed'
          respond_to do |format|
            format.json {
              render json: {
                success: false,
                message: "Upload failed: #{error_message}",
                errors: @document.errors.full_messages
              }, status: :unprocessable_entity
            }
            format.html {
              redirect_to edit_admin_customer_path(@customer), alert: "Upload failed: #{error_message}"
            }
          end
        end
      else
        @document.destroy
        respond_to do |format|
          format.json {
            render json: {
              success: false,
              message: 'No file provided',
              errors: ['Document file is required']
            }, status: :unprocessable_entity
          }
          format.html {
            redirect_to edit_admin_customer_path(@customer), alert: 'No file provided'
          }
        end
      end
    else
      respond_to do |format|
        format.json {
          render json: {
            success: false,
            message: 'Failed to create document record',
            errors: @document.errors.full_messages
          }, status: :unprocessable_entity
        }
        format.html {
          redirect_to edit_admin_customer_path(@customer), alert: 'Failed to create document record'
        }
      end
    end
  end

  # DELETE /admin/customers/:customer_id/documents/:id
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

  # GET /admin/customers/:customer_id/documents/:id/download
  def download
    document = @customer.documents.find(params[:id])
    if document.has_file?
      redirect_to document.document_url, allow_other_host: true
    else
      redirect_to admin_customer_path(@customer), alert: 'Document not found'
    end
  end

  private

  def set_customer
    @customer = Customer.find(params[:customer_id])
  end

  def set_document
    @document = @customer.documents.find(params[:id])
  end

  def document_params
    params.require(:customer_document).permit(:document_type, :document_file)
  end
end