class Admin::MotorInsuranceDocumentsController < Admin::ApplicationController
  before_action :set_motor_insurance
  before_action :set_document, only: [:show, :destroy]

  # GET /admin/motor_insurances/:motor_insurance_id/documents
  def index
    @documents = @motor_insurance.motor_insurance_documents.order(:created_at)
    respond_to do |format|
      format.json do
        render json: {
          documents: @documents.map do |doc|
            {
              id: doc.id,
              title: doc.title,
              document_type: doc.document_type,
              filename: doc.document_name,
              size: doc.document_size,
              url: doc.document_url,
              created_at: doc.created_at.strftime('%B %d, %Y')
            }
          end
        }
      end
    end
  end

  # POST /admin/motor_insurances/:motor_insurance_id/documents
  def create
    @document = @motor_insurance.motor_insurance_documents.build(document_params)

    if @document.save
      # Handle file upload to R2
      if params[:motor_insurance_document][:document_file].present?
        result = @document.upload_to_r2(params[:motor_insurance_document][:document_file])

        if result.is_a?(Hash) && result[:success]
          render json: {
            success: true,
            message: 'Document uploaded successfully!',
            document: {
              id: @document.id,
              title: @document.title,
              document_type: @document.document_type,
              filename: @document.document_name,
              size: @document.document_size,
              url: @document.document_url,
              created_at: @document.created_at.strftime('%B %d, %Y')
            }
          }
        else
          @document.destroy
          error_message = result.is_a?(Hash) ? result[:error] : 'Upload failed'
          render json: {
            success: false,
            message: "Upload failed: #{error_message}",
            errors: @document.errors.full_messages
          }, status: :unprocessable_entity
        end
      else
        @document.destroy
        render json: {
          success: false,
          message: 'No file provided',
          errors: ['Document file is required']
        }, status: :unprocessable_entity
      end
    else
      render json: {
        success: false,
        message: 'Failed to create document record',
        errors: @document.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /admin/motor_insurances/:motor_insurance_id/documents/:id
  def destroy
    # Delete from R2 first
    @document.delete_from_r2 if @document.has_file?

    if @document.destroy
      render json: {
        success: true,
        message: 'Document deleted successfully!'
      }
    else
      render json: {
        success: false,
        message: 'Failed to delete document'
      }, status: :unprocessable_entity
    end
  end

  # GET /admin/motor_insurances/:motor_insurance_id/documents/:id/download
  def download
    document = @motor_insurance.motor_insurance_documents.find(params[:id])
    if document.has_file?
      redirect_to document.document_url, allow_other_host: true
    else
      redirect_to admin_motor_insurance_path(@motor_insurance), alert: 'Document not found'
    end
  end

  private

  def set_motor_insurance
    @motor_insurance = MotorInsurance.find(params[:motor_insurance_id])
  end

  def set_document
    @document = @motor_insurance.motor_insurance_documents.find(params[:id])
  end

  def document_params
    params.require(:motor_insurance_document).permit(:document_type, :title, :description, :document_file)
  end
end