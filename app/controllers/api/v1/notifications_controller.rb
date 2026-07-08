class Api::V1::NotificationsController < Api::V1::ApplicationController
  before_action :authenticate_api_user
  before_action :set_recipient, only: [:index, :show, :mark_as_read, :mark_as_unread, :mark_all_as_read]

  # GET /api/v1/notifications
  # Get all notifications for the authenticated user or specific recipient
  def index
    @notifications = base_notifications
                    .includes(:recipient, :reference)
                    .page(params[:page])
                    .per(params[:per_page] || 20)

    # Apply filters if provided
    @notifications = @notifications.where(notification_type: params[:type]) if params[:type].present?
    @notifications = @notifications.where(is_read: params[:is_read]) if params[:is_read].present?

    render json: {
      status: 'success',
      data: {
        notifications: @notifications.map { |notification| notification_json(notification) },
        pagination: {
          current_page: @notifications.current_page,
          total_pages: @notifications.total_pages,
          total_count: @notifications.total_count,
          per_page: @notifications.limit_value
        }
      }
    }
  end

  # GET /api/v1/notifications/:id
  # Get specific notification details
  def show
    @notification = base_notifications.find(params[:id])

    render json: {
      status: 'success',
      data: {
        notification: notification_json(@notification, detailed: true)
      }
    }
  rescue ActiveRecord::RecordNotFound
    render json: {
      status: 'error',
      message: 'Notification not found'
    }, status: :not_found
  end

  # GET /api/v1/notifications/unread_count
  # Get count of unread notifications
  def unread_count
    count = base_notifications.unread.count

    render json: {
      status: 'success',
      data: {
        unread_count: count
      }
    }
  end

  # GET /api/v1/notifications/recent
  # Get recent notifications (last 10)
  def recent
    @notifications = base_notifications
                    .includes(:recipient, :reference)
                    .recent
                    .limit(10)

    render json: {
      status: 'success',
      data: {
        notifications: @notifications.map { |notification| notification_json(notification) }
      }
    }
  end

  # PATCH /api/v1/notifications/:id/mark_as_read
  # Mark specific notification as read
  def mark_as_read
    @notification = base_notifications.find(params[:id])
    @notification.mark_as_read!

    render json: {
      status: 'success',
      message: 'Notification marked as read',
      data: {
        notification: notification_json(@notification)
      }
    }
  rescue ActiveRecord::RecordNotFound
    render json: {
      status: 'error',
      message: 'Notification not found'
    }, status: :not_found
  end

  # PATCH /api/v1/notifications/:id/mark_as_unread
  # Mark specific notification as unread
  def mark_as_unread
    @notification = base_notifications.find(params[:id])
    @notification.mark_as_unread!

    render json: {
      status: 'success',
      message: 'Notification marked as unread',
      data: {
        notification: notification_json(@notification)
      }
    }
  rescue ActiveRecord::RecordNotFound
    render json: {
      status: 'error',
      message: 'Notification not found'
    }, status: :not_found
  end

  # PATCH /api/v1/notifications/mark_all_as_read
  # Mark all notifications as read for the recipient
  def mark_all_as_read
    updated_count = base_notifications.unread.update_all(
      is_read: true,
      read_at: Time.current
    )

    render json: {
      status: 'success',
      message: 'All notifications marked as read',
      data: {
        updated_count: updated_count
      }
    }
  end

  # GET /api/v1/notifications/types
  # Get available notification types
  def types
    render json: {
      status: 'success',
      data: {
        notification_types: Notification::NOTIFICATION_TYPES.map do |type|
          {
            value: type,
            label: type.humanize.titleize
          }
        end
      }
    }
  end

  private

  def authenticate_api_user
    Rails.logger.info "=== 🔐 Notifications API Authentication Started ==="

    @current_user = nil

    # 1. Try JWT token authentication
    if request.headers['Authorization'].present?
      token = request.headers['Authorization'].sub(/^Bearer\s+/, '')
      Rails.logger.info "🔑 JWT Token found (first 20 chars): #{token[0..19]}..."

      begin
        result = AuthorizeApiRequest.new(request.headers).call
        @current_user = result[:user]

        if @current_user
          Rails.logger.info "✅ JWT Authentication successful: User #{@current_user.id} - #{@current_user.email}"
          Rails.logger.info "🎯 Authentication complete - proceeding with request"
          return true
        else
          Rails.logger.warn "⚠️ JWT service returned no user"
        end
      rescue => e
        Rails.logger.error "❌ JWT Authentication failed: #{e.class.name} - #{e.message}"
        Rails.logger.error "   Backtrace: #{e.backtrace.first(3).join('; ')}"
      end
    else
      Rails.logger.info "ℹ️ No Authorization header present"
    end

    # 2. Try session authentication (for web browsers)
    begin
      if defined?(user_signed_in?) && user_signed_in?
        @current_user = current_user
        Rails.logger.info "✅ Session Authentication successful: User #{@current_user.id} - #{@current_user.email}"
        return true
      else
        Rails.logger.info "ℹ️ No active session found"
      end
    rescue => e
      Rails.logger.warn "⚠️ Session auth check failed: #{e.message}"
    end

    # Authentication failed - render JSON error response
    Rails.logger.error "❌ Authentication failed - returning 401 Unauthorized"
    Rails.logger.info "📋 Request Summary:"
    Rails.logger.info "   - Path: #{request.path}"
    Rails.logger.info "   - Method: #{request.method}"
    Rails.logger.info "   - Has Auth header: #{request.headers['Authorization'].present?}"
    Rails.logger.info "   - Session available: #{defined?(user_signed_in?)}"
    Rails.logger.info "   - Content Type: #{request.headers['Content-Type']}"

    render json: {
      status: 'error',
      message: 'Authentication required. Please provide a valid JWT token or login through the web interface.',
      code: 'AUTH_REQUIRED',
      details: {
        has_auth_header: request.headers['Authorization'].present?,
        session_available: defined?(user_signed_in?),
        path: request.path
      }
    }, status: :unauthorized

    return false
  end

  def set_recipient
    # Determine recipient based on parameters or current user
    if params[:recipient_type].present? && params[:recipient_id].present?
      @recipient_type = params[:recipient_type]
      @recipient_id = params[:recipient_id]
    else
      # Auto-detect recipient type based on current user's type and associations
      user = @current_user

      case user.user_type
      when 'sub_agent'
        # For sub_agent users, check if there's a SubAgent with same ID
        if SubAgent.exists?(id: user.id)
          @recipient_type = 'SubAgent'
          @recipient_id = user.id
        else
          @recipient_type = 'User'
          @recipient_id = user.id
        end
      when 'customer'
        # For customer users, check if there's a Customer record
        if Customer.exists?(id: user.id)
          @recipient_type = 'Customer'
          @recipient_id = user.id
        elsif Customer.exists?(user_id: user.id)
          customer = Customer.find_by(user_id: user.id)
          @recipient_type = 'Customer'
          @recipient_id = customer.id
        else
          @recipient_type = 'User'
          @recipient_id = user.id
        end
      else
        # Default to User for admin, agent, or other types
        @recipient_type = 'User'
        @recipient_id = user.id
      end
    end
  end

  def base_notifications
    if @recipient_type && @recipient_id
      Notification.where(recipient_type: @recipient_type, recipient_id: @recipient_id)
    else
      Notification.none
    end
  end

  def notification_json(notification, detailed: false)
    base_data = {
      id: notification.id,
      type: notification.notification_type,
      title: notification.title,
      message: notification.message,
      is_read: notification.is_read,
      sent_at: notification.sent_at&.iso8601,
      read_at: notification.read_at&.iso8601,
      recipient: {
        type: notification.recipient_type,
        id: notification.recipient_id
      }
    }

    if detailed
      base_data.merge!({
        reference: notification.reference ? {
          type: notification.reference_type,
          id: notification.reference_id
        } : nil,
        created_at: notification.created_at&.iso8601,
        updated_at: notification.updated_at&.iso8601
      })
    end

    base_data
  end
end