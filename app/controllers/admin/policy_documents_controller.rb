class Admin::PolicyDocumentsController < Admin::ApplicationController
  before_action :set_policy_document, only: [:show, :download, :destroy]
  before_action :validate_policy_params, only: [:index, :create]

  # GET /admin/policy_documents
  def index
    @policy_documents = PolicyDocument.for_policy(params[:policy_type], params[:policy_id])
                                     .order(created_at: :desc)
    @policy_object = get_policy_object

    # Return JSON response for AJAX requests
    if request.xhr? || request.format.json?
      render json: {
        success: true,
        policy_documents: @policy_documents.map do |doc|
          {
            id: doc.id,
            title: doc.title,
            document_type: doc.document_type,
            description: doc.description,
            filename: doc.document_name,
            document_size: doc.document_size,
            document_url: doc.document_url,
            download_url: doc.download_url,
            r2_content_type: doc.r2_content_type,
            uploaded_by: doc.uploaded_by,
            created_at: doc.created_at.strftime('%B %d, %Y at %I:%M %p')
          }
        end
      }
    else
      # For non-AJAX requests, redirect to policy page
      redirect_to "/admin/insurance/life/#{params[:policy_id]}", notice: 'Please access documents through the policy page.'
    end
  end

  # POST /admin/policy_documents
  def create
    # Get policy params from the form data
    policy_type = params[:policy_type] || params[:policy_document][:policy_type]
    policy_id = params[:policy_id] || params[:policy_document][:policy_id]

    @policy_document = PolicyDocument.new(policy_document_params)
    @policy_document.policy_type = policy_type
    @policy_document.policy_id = policy_id
    @policy_document.uploaded_by = current_user&.email || 'System'

    if @policy_document.save
      # Handle file upload if present
      if params[:policy_document][:file].present?
        upload_result = @policy_document.upload_to_r2(params[:policy_document][:file])

        if upload_result[:error]
          @policy_document.destroy
          render json: {
            success: false,
            error: "Document saved but file upload failed: #{upload_result[:error]}"
          }
          return
        end
      end

      render json: {
        success: true,
        message: 'Document uploaded successfully',
        document: {
          id: @policy_document.id,
          title: @policy_document.title,
          document_type: @policy_document.document_type,
          filename: @policy_document.document_name,
          size: @policy_document.document_size,
          url: @policy_document.document_url,
          created_at: @policy_document.created_at.strftime('%B %d, %Y at %I:%M %p')
        }
      }
    else
      render json: {
        success: false,
        error: @policy_document.errors.full_messages.join(', ')
      }
    end
  end

  # GET /admin/policy_documents/:id
  def show
    render json: {
      document: {
        id: @policy_document.id,
        title: @policy_document.title,
        document_type: @policy_document.document_type,
        description: @policy_document.description,
        filename: @policy_document.document_name,
        size: @policy_document.document_size,
        url: @policy_document.document_url,
        uploaded_by: @policy_document.uploaded_by,
        created_at: @policy_document.created_at.strftime('%B %d, %Y at %I:%M %p')
      }
    }
  end

  # GET /admin/policy_documents/:id/download
  def download
    if @policy_document.has_r2_document?
      redirect_to @policy_document.document_url, allow_other_host: true
    else
      render json: { error: 'Document not found' }, status: :not_found
    end
  end

  # DELETE /admin/policy_documents/:id
  def destroy
    if @policy_document.delete_from_r2 && @policy_document.destroy
      render json: {
        success: true,
        message: 'Document deleted successfully'
      }
    else
      render json: {
        success: false,
        error: 'Failed to delete document'
      }
    end
  end

  private

  def set_policy_document
    @policy_document = PolicyDocument.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Document not found' }, status: :not_found
  end

  def validate_policy_params
    unless params[:policy_type].present? && params[:policy_id].present?
      render json: { error: 'Policy type and ID are required' }, status: :bad_request
      return false
    end

    unless ['health', 'life', 'motor', 'other'].include?(params[:policy_type])
      render json: { error: 'Invalid policy type' }, status: :bad_request
      return false
    end

    true
  end

  def policy_document_params
    params.require(:policy_document).permit(:document_type, :title, :description)
  end

  def get_policy_object
    case params[:policy_type]
    when 'health'
      HealthInsurance.find_by(id: params[:policy_id])
    when 'life'
      LifeInsurance.find_by(id: params[:policy_id])
    when 'motor'
      MotorInsurance.find_by(id: params[:policy_id])
    when 'other'
      OtherInsurance.find_by(id: params[:policy_id])
    end
  end
end