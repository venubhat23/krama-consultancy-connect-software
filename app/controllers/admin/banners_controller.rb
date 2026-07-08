class Admin::BannersController < Admin::ApplicationController
  before_action :set_banner, only: [:show, :edit, :update, :destroy, :toggle_status]

  # GET /admin/banners
  def index
    @banners = Banner.order(:display_order, :created_at)
                    .page(params[:page]).per(25)

    # Filter by status if specified
    case params[:status]
    when 'active'
      @banners = @banners.active
    when 'inactive'
      @banners = @banners.inactive
    when 'current'
      @banners = @banners.current
    end

    # Filter by location if specified
    if params[:location].present?
      @banners = @banners.by_location(params[:location])
    end

    # Statistics for dashboard cards
    @stats = {
      total_banners: Banner.count,
      active_banners: Banner.active.count,
      current_banners: Banner.current.count,
      expired_banners: Banner.where('display_end_date < ?', Date.current).count
    }
  end

  # GET /admin/banners/1
  def show
  end

  # GET /admin/banners/new
  def new
    @banner = Banner.new
    @banner.display_start_date = Date.current
    @banner.display_end_date = 1.month.from_now
    @banner.display_order = (Banner.maximum(:display_order) || 0) + 1
  end

  # GET /admin/banners/1/edit
  def edit
  end

  # POST /admin/banners
  def create
    @banner = Banner.new(banner_params.except(:banner_image))

    # Handle banner image upload to R2
    if params[:banner][:banner_image].present?
      file = params[:banner][:banner_image]

      begin
        result = R2Service.upload(file, folder: "banners")

        if result && result[:key] && !result[:error]
          @banner.r2_file_key = result[:key]
          @banner.r2_filename = result[:filename]
          @banner.r2_content_type = result[:content_type]
          @banner.r2_file_size = result[:size]
          @banner.r2_public_url = result[:public_url]
        else
          @banner.errors.add(:banner_image, "Failed to upload banner image: #{result[:error] || 'Unknown error'}")
        end
      rescue => e
        Rails.logger.error "Banner image upload failed: #{e.message}"
        @banner.errors.add(:banner_image, "Upload failed: #{e.message}")
      end
    end

    if @banner.save
      redirect_to admin_banner_path(@banner), notice: 'Banner was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /admin/banners/1
  def update
    Rails.logger.info "Banner update attempt - ID: #{@banner.id}, Params: #{banner_params.inspect}"

    # Handle banner image upload to R2 if a new image is provided
    if params[:banner][:banner_image].present?
      file = params[:banner][:banner_image]

      begin
        # Delete old image from R2 if it exists
        if @banner.r2_file_key.present?
          R2Service.delete(@banner.r2_file_key)
        end

        result = R2Service.upload(file, folder: "banners")

        if result && result[:key] && !result[:error]
          @banner.r2_file_key = result[:key]
          @banner.r2_filename = result[:filename]
          @banner.r2_content_type = result[:content_type]
          @banner.r2_file_size = result[:size]
          @banner.r2_public_url = result[:public_url]
        else
          @banner.errors.add(:banner_image, "Failed to upload banner image: #{result[:error] || 'Unknown error'}")
          flash.now[:alert] = "Unable to update banner. Please check the errors below."
          render :edit, status: :unprocessable_entity
          return
        end
      rescue => e
        Rails.logger.error "Banner image upload failed: #{e.message}"
        @banner.errors.add(:banner_image, "Upload failed: #{e.message}")
        flash.now[:alert] = "Unable to update banner. Please check the errors below."
        render :edit, status: :unprocessable_entity
        return
      end
    end

    if @banner.update(banner_params.except(:banner_image))
      Rails.logger.info "Banner successfully updated - ID: #{@banner.id}, Title: #{@banner.title}"
      redirect_to admin_banner_path(@banner), notice: 'Banner was successfully updated.'
    else
      Rails.logger.error "Banner update failed - ID: #{@banner.id}, Errors: #{@banner.errors.full_messages}"
      flash.now[:alert] = "Unable to update banner. Please check the errors below."
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/banners/1
  def destroy
    # Delete banner image from R2 if it exists
    if @banner.r2_file_key.present?
      begin
        R2Service.delete(@banner.r2_file_key)
      rescue => e
        Rails.logger.error "Failed to delete banner image from R2: #{e.message}"
      end
    end

    @banner.destroy
    redirect_to admin_banners_path, notice: 'Banner was successfully deleted.'
  end

  # PATCH /admin/banners/1/toggle_status
  def toggle_status
    @banner.update(status: !@banner.status)
    status_text = @banner.status? ? 'activated' : 'deactivated'
    redirect_to admin_banners_path, notice: "Banner was successfully #{status_text}."
  end

  private

  def set_banner
    @banner = Banner.find(params[:id])
  end

  def banner_params
    params.require(:banner).permit(
      :title, :description, :redirect_link, :display_start_date, :display_end_date,
      :display_location, :status, :display_order, :banner_image,
      :r2_file_key, :r2_filename, :r2_content_type, :r2_file_size, :r2_public_url
    )
  end
end