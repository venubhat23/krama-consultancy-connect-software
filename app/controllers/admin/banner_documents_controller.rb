class Admin::BannerDocumentsController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_banner, only: [:create]
  before_action :set_banner_document, only: [:show, :destroy, :download]

  def create
    @banner_document = @banner.banner_documents.build(banner_document_params)

    if @banner_document.save
      # Handle file upload to R2 if document_file is present
      if params[:banner_document][:document_file].present?
        upload_result = @banner_document.upload_to_r2(params[:banner_document][:document_file])

        if upload_result[:success]
          render json: {
            success: true,
            document: {
              id: @banner_document.id,
              title: @banner_document.title,
              document_type: @banner_document.document_type,
              file_size: @banner_document.file_size_mb,
              document_url: @banner_document.document_url,
              download_url: @banner_document.download_url,
              created_at: @banner_document.created_at.strftime('%B %d, %Y')
            }
          }
        else
          @banner_document.destroy
          render json: { success: false, error: upload_result[:error] }
        end
      else
        render json: {
          success: true,
          document: {
            id: @banner_document.id,
            title: @banner_document.title,
            document_type: @banner_document.document_type
          }
        }
      end
    else
      render json: {
        success: false,
        error: @banner_document.errors.full_messages.join(', ')
      }
    end
  end

  def show
    if @banner_document.document_url.present?
      redirect_to @banner_document.document_url
    else
      redirect_to admin_banner_path(@banner_document.banner), alert: 'Document not found'
    end
  end

  def download
    if @banner_document.download_url.present?
      redirect_to @banner_document.download_url
    else
      redirect_to admin_banner_path(@banner_document.banner), alert: 'Download not available'
    end
  end

  def destroy
    banner = @banner_document.banner

    begin
      # Delete from R2 if file exists
      if @banner_document.has_file?
        delete_result = @banner_document.delete_from_r2
        unless delete_result
          Rails.logger.warn "Failed to delete file from R2 for banner document #{@banner_document.id}"
        end
      end

      # Delete the database record
      @banner_document.destroy!

      render json: {
        success: true,
        message: 'Banner document deleted successfully',
        remaining_count: banner.banner_documents.count
      }
    rescue => e
      Rails.logger.error "Failed to delete banner document: #{e.message}"
      render json: {
        success: false,
        error: "Failed to delete document: #{e.message}"
      }
    end
  end

  private

  def set_banner
    @banner = Banner.find(params[:banner_id])
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: 'Banner not found' }
  end

  def set_banner_document
    @banner_document = BannerDocument.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: 'Banner document not found' } and return
  end

  def banner_document_params
    params.require(:banner_document).permit(:document_type, :title, :description)
  end
end