class Api::V1::Mobile::BannersController < Api::V1::Mobile::BaseController
  # GET /api/v1/mobile/banners
  def index
    begin
      # Fetch all banners with ordering by display_order and creation date
      banners = Banner.ordered
                     .map do |banner|
        banner_data = {
          id: banner.id,
          title: banner.title,
          description: banner.description,
          redirect_link: banner.redirect_link,
          display_start_date: banner.display_start_date,
          display_end_date: banner.display_end_date,
          display_location: banner.display_location,
          display_location_humanized: banner.display_location_humanized,
          status: banner.status,
          display_order: banner.display_order,
          created_at: banner.created_at,
          updated_at: banner.updated_at,
          active: banner.active?,
          current: banner.current?,
          expired: banner.expired?,
          upcoming: banner.upcoming?
        }

        # Add banner image URL if available in R2
        if banner.has_r2_image?
          banner_data[:banner_image] = {
            url: banner.banner_image_url,
            filename: banner.r2_filename,
            content_type: banner.r2_content_type,
            byte_size: banner.r2_file_size
          }
        else
          banner_data[:banner_image] = nil
        end

        banner_data
      end

      render json: {
        success: true,
        message: 'Banners fetched successfully',
        data: banners,
        meta: {
          total_count: Banner.count,
          active_count: Banner.active.count,
          current_count: Banner.active.current.count,
          locations: Banner.display_locations.keys
        }
      }, status: :ok

    rescue => e
      Rails.logger.error "Error fetching banners: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      render json: {
        success: false,
        message: 'Failed to fetch banners',
        error: e.message,
        data: []
      }, status: :internal_server_error
    end
  end

  # GET /api/v1/mobile/banners/active
  def active
    begin
      # Fetch only active and current banners
      banners = Banner.active
                     .current
                     .ordered
                     .map do |banner|
        banner_data = {
          id: banner.id,
          title: banner.title,
          description: banner.description,
          redirect_link: banner.redirect_link,
          display_start_date: banner.display_start_date,
          display_end_date: banner.display_end_date,
          display_location: banner.display_location,
          display_location_humanized: banner.display_location_humanized,
          display_order: banner.display_order,
          created_at: banner.created_at,
          updated_at: banner.updated_at
        }

        # Add banner image URL if available in R2
        if banner.has_r2_image?
          banner_data[:banner_image] = {
            url: banner.banner_image_url,
            filename: banner.r2_filename,
            content_type: banner.r2_content_type,
            byte_size: banner.r2_file_size
          }
        else
          banner_data[:banner_image] = nil
        end

        banner_data
      end

      render json: {
        success: true,
        message: 'Active banners fetched successfully',
        data: banners,
        meta: {
          count: banners.length,
          locations: Banner.display_locations.keys
        }
      }, status: :ok

    rescue => e
      Rails.logger.error "Error fetching active banners: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      render json: {
        success: false,
        message: 'Failed to fetch active banners',
        error: e.message,
        data: []
      }, status: :internal_server_error
    end
  end

  # GET /api/v1/mobile/banners/by_location?location=dashboard
  def by_location
    begin
      location = params[:location]

      unless Banner.display_locations.keys.include?(location)
        return render json: {
          success: false,
          message: 'Invalid location parameter',
          error: "Location must be one of: #{Banner.display_locations.keys.join(', ')}",
          data: []
        }, status: :bad_request
      end

      # Fetch banners for specific location that are active and current
      banners = Banner.active
                     .current
                     .by_location(location)
                     .ordered
                     .map do |banner|
        banner_data = {
          id: banner.id,
          title: banner.title,
          description: banner.description,
          redirect_link: banner.redirect_link,
          display_start_date: banner.display_start_date,
          display_end_date: banner.display_end_date,
          display_location: banner.display_location,
          display_location_humanized: banner.display_location_humanized,
          display_order: banner.display_order,
          created_at: banner.created_at,
          updated_at: banner.updated_at
        }

        # Add banner image URL if available in R2
        if banner.has_r2_image?
          banner_data[:banner_image] = {
            url: banner.banner_image_url,
            filename: banner.r2_filename,
            content_type: banner.r2_content_type,
            byte_size: banner.r2_file_size
          }
        else
          banner_data[:banner_image] = nil
        end

        banner_data
      end

      render json: {
        success: true,
        message: "Banners for #{location} fetched successfully",
        data: banners,
        meta: {
          location: location,
          count: banners.length
        }
      }, status: :ok

    rescue => e
      Rails.logger.error "Error fetching banners by location: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      render json: {
        success: false,
        message: 'Failed to fetch banners by location',
        error: e.message,
        data: []
      }, status: :internal_server_error
    end
  end

  # GET /api/v1/mobile/banners/:id
  def show
    begin
      banner = Banner.find(params[:id])

      banner_data = {
        id: banner.id,
        title: banner.title,
        description: banner.description,
        redirect_link: banner.redirect_link,
        display_start_date: banner.display_start_date,
        display_end_date: banner.display_end_date,
        display_location: banner.display_location,
        display_location_humanized: banner.display_location_humanized,
        status: banner.status,
        display_order: banner.display_order,
        created_at: banner.created_at,
        updated_at: banner.updated_at,
        active: banner.active?,
        current: banner.current?,
        expired: banner.expired?,
        upcoming: banner.upcoming?
      }

      # Add banner image URL if available in R2
      if banner.has_r2_image?
        banner_data[:banner_image] = {
          url: banner.banner_image_url,
          filename: banner.r2_filename,
          content_type: banner.r2_content_type,
          byte_size: banner.r2_file_size
        }
      else
        banner_data[:banner_image] = nil
      end

      render json: {
        success: true,
        message: 'Banner fetched successfully',
        data: banner_data
      }, status: :ok

    rescue ActiveRecord::RecordNotFound
      render json: {
        success: false,
        message: 'Banner not found',
        data: nil
      }, status: :not_found

    rescue => e
      Rails.logger.error "Error fetching banner: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      render json: {
        success: false,
        message: 'Failed to fetch banner',
        error: e.message,
        data: nil
      }, status: :internal_server_error
    end
  end
end