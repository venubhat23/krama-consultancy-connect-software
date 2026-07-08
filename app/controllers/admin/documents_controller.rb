class Admin::DocumentsController < Admin::ApplicationController
  before_action :set_document, only: [:show, :edit, :update, :destroy, :download]
  before_action :set_documentable, only: [:index, :new, :create]

  # GET /admin/documents or /admin/users/1/documents
  def index
    if @documentable
      @documents = @documentable.uploaded_documents.recent.page(params[:page]).per(10)
      @page_title = "Documents for #{@documentable.class.name} ##{@documentable.id}"
    else
      @documents = Document.includes(:documentable).recent.page(params[:page]).per(20)
      @page_title = "All Documents"
    end

    # Filter by document type if provided
    @documents = @documents.by_type(params[:document_type]) if params[:document_type].present?

    # Statistics
    @total_documents = @documentable ? @documentable.uploaded_documents.count : Document.count
    @document_types_count = (@documentable ? @documentable.uploaded_documents : Document).group(:document_type).count
  end

  # GET /admin/documents/1
  def show
    @related_documents = @document.documentable.uploaded_documents.where.not(id: @document.id).limit(5)
  end

  # GET /admin/documents/new or /admin/users/1/documents/new
  def new
    if @documentable
      @document = @documentable.uploaded_documents.build
    else
      @document = Document.new
    end
  end

  # GET /admin/documents/1/edit
  def edit
  end

  # POST /admin/documents or /admin/users/1/documents
  def create
    if @documentable
      @document = @documentable.uploaded_documents.build(document_params)
      @document.uploaded_by = current_user_name
      redirect_path = polymorphic_path([:admin, @documentable, :documents])
    else
      @document = Document.new(document_params)
      @document.uploaded_by = current_user_name
      redirect_path = admin_documents_path
    end

    if @document.save
      redirect_to redirect_path, notice: 'Document was successfully uploaded.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /admin/documents/1
  def update
    respond_to do |format|
      if @document.update(document_params.except(:file))
        format.json { render json: { success: true, message: 'Document updated successfully' } }
        format.html { redirect_to admin_document_path(@document), notice: 'Document was successfully updated.' }
      else
        format.json { render json: { success: false, errors: @document.errors.full_messages } }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /admin/documents/1
  def destroy
    documentable = @document.documentable

    begin
      @document.destroy!

      respond_to do |format|
        format.json { render json: { success: true, message: 'Document deleted successfully' } }
        format.html do
          if documentable && params[:return_to_record] == 'true'
            redirect_to polymorphic_path([:admin, documentable, :documents]), notice: 'Document was successfully deleted.'
          else
            redirect_to admin_documents_path, notice: 'Document was successfully deleted.'
          end
        end
      end
    rescue ActiveRecord::RecordNotDestroyed => e
      respond_to do |format|
        format.json { render json: { success: false, error: e.message } }
        format.html { redirect_to admin_documents_path, alert: "Failed to delete document: #{e.message}" }
      end
    end
  end

  # GET /admin/documents/1/download
  def download
    if @document.file.attached?
      redirect_to rails_blob_path(@document.file, disposition: "attachment")
    else
      redirect_to admin_documents_path, alert: 'File not found.'
    end
  end

  # Serve investor documents securely
  def show_investor_document
    @investor = Investor.find(params[:investor_id])

    if params[:type] == 'main' && @investor.upload_main_document.attached?
      blob = @investor.upload_main_document
    elsif params[:document_id].present?
      document = @investor.investor_documents.find(params[:document_id])
      blob = document.document_file if document&.document_file&.attached?
    end

    if blob
      # Use Rails blob path which handles signed URLs properly
      redirect_to rails_blob_path(blob, only_path: false), allow_other_host: true
    else
      redirect_to admin_investors_path, alert: 'Document not found'
    end
  end

  # Download investor documents
  def download_investor_document
    @investor = Investor.find(params[:investor_id])

    if params[:type] == 'main' && @investor.upload_main_document.attached?
      blob = @investor.upload_main_document
    elsif params[:document_id].present?
      document = @investor.investor_documents.find(params[:document_id])
      blob = document.document_file if document&.document_file&.attached?
    end

    if blob
      # Use Rails blob path for downloads with proper content disposition
      redirect_to rails_blob_path(blob, disposition: 'attachment', only_path: false), allow_other_host: true
    else
      redirect_to admin_investors_path, alert: 'Document not found'
    end
  end

  # Handle blob access with proper error handling
  def blob_access
    blob = ActiveStorage::Blob.find_by(key: params[:key])

    if blob.nil?
      render_document_error("Document not found")
      return
    end

    service = blob.service
    file_path = service.send(:path_for, blob.key)

    if File.exist?(file_path)
      # Set proper URL options
      ActiveStorage::Current.url_options = {
        host: request.host,
        port: request.port,
        protocol: request.protocol
      }

      redirect_to blob.url, allow_other_host: true
    else
      render_document_error("Document file missing from storage", blob.filename)
    end
  rescue => e
    Rails.logger.error "Error accessing document: #{e.message}"
    render_document_error("Error accessing document: #{e.message}")
  end

  private

  def render_document_error(message, filename = nil)
    render html: generate_error_html(message, filename), status: :not_found
  end

  def generate_error_html(message, filename = nil)
    <<~HTML.html_safe
      <!DOCTYPE html>
      <html>
      <head>
        <title>Document Error</title>
        <style>
          body {
            font-family: Arial, sans-serif;
            padding: 50px;
            background-color: #f8f9fa;
          }
          .error-container {
            max-width: 600px;
            margin: 0 auto;
            background: white;
            padding: 40px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            text-align: center;
          }
          .error-icon {
            font-size: 48px;
            margin-bottom: 20px;
            color: #dc3545;
          }
          .error-message {
            color: #dc3545;
            margin-bottom: 20px;
            font-size: 18px;
          }
          .filename {
            color: #6c757d;
            font-style: italic;
            margin-bottom: 30px;
          }
          .btn-back {
            background-color: #007bff;
            color: white;
            padding: 12px 24px;
            text-decoration: none;
            border-radius: 4px;
            display: inline-block;
          }
          .btn-back:hover {
            background-color: #0056b3;
          }
        </style>
      </head>
      <body>
        <div class="error-container">
          <div class="error-icon">📄❌</div>
          <div class="error-message">#{message}</div>
          #{filename ? "<div class=\"filename\">File: #{filename}</div>" : ''}
          <a href="javascript:window.close()" class="btn-back">Close Window</a>
          <a href="javascript:history.back()" class="btn-back" style="margin-left: 10px;">Go Back</a>
        </div>
      </body>
      </html>
    HTML
  end

  private

  def set_document
    @document = Document.find(params[:id])
  end

  def set_documentable
    # Support nested routes like /admin/users/1/documents
    if params[:user_id]
      @documentable = User.find(params[:user_id])
    elsif params[:lead_id]
      @documentable = Lead.find(params[:lead_id])
    elsif params[:customer_id]
      @documentable = Customer.find(params[:customer_id])
    elsif params[:documentable_type] && params[:documentable_id]
      @documentable = params[:documentable_type].constantize.find(params[:documentable_id])
    end
  end

  def document_params
    params.require(:document).permit(:title, :document_name, :description, :document_type, :file, :documentable_type, :documentable_id)
  end

  def current_user_name
    # You can customize this based on your user authentication system
    if respond_to?(:current_user) && current_user
      "#{current_user.first_name} #{current_user.last_name}".strip
    else
      'Admin User'
    end
  end
end