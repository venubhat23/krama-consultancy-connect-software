class Api::V1::Mobile::BaseController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  skip_load_and_authorize_resource
  before_action :set_default_response_format

  # Override devise's authenticate_user! to prevent HTML redirects
  def authenticate_user!
    # For mobile APIs, we don't want to redirect to HTML login page
    # This method will be overridden by specific authentication methods
  end

  private

  def set_default_response_format
    request.format = :json
  end

  def authenticate_customer!
    Rails.logger.info "=== AUTHENTICATION START ==="
    token = request.headers['Authorization']&.split(' ')&.last
    Rails.logger.info "Token extracted: #{token&.first(20)}..."

    if token.blank?
      Rails.logger.info "No token found"
      return render json: {
        success: false,
        message: 'Authorization token is required'
      }, status: :unauthorized
    end

    begin
      Rails.logger.info "Attempting to decode token..."
      decoded_token = JWT.decode(token, Rails.application.secret_key_base)[0]
      Rails.logger.info "Token decoded successfully: #{decoded_token}"
      user_id = decoded_token['user_id']
      role = decoded_token['role']

      case role
      when 'customer', 'client'
        # For customers, user_id is the User record ID, need to find associated Customer
        user_record = User.find(user_id)
        @current_user = Customer.find_by(email: user_record.email)
        if @current_user.nil?
          return render json: {
            success: false,
            message: 'Customer account not found'
          }, status: :unauthorized
        end
      when 'agent'
        @current_user = User.find(user_id)
      when 'sub_agent'
        @current_user = SubAgent.find(user_id)
      else
        return render json: {
          success: false,
          message: 'Invalid user role'
        }, status: :unauthorized
      end

      if @current_user.nil?
        return render json: {
          success: false,
          message: 'User not found'
        }, status: :unauthorized
      end

    rescue JWT::DecodeError => e
      render json: {
        success: false,
        message: 'Invalid authorization token'
      }, status: :unauthorized
    rescue ActiveRecord::RecordNotFound => e
      render json: {
        success: false,
        message: 'User not found'
      }, status: :unauthorized
    end
  end

  def current_user
    @current_user
  end

  def current_customer
    current_user if current_user.is_a?(Customer)
  end

  def current_agent
    current_user if current_user.is_a?(User)
  end

  def current_sub_agent
    current_user if current_user.is_a?(SubAgent)
  end

  # Helper method to handle errors
  def render_error(message, status = :bad_request, errors = nil)
    response = {
      success: false,
      message: message
    }
    response[:errors] = errors if errors.present?

    render json: response, status: status
  end

  # Helper method to handle success
  def render_success(data = nil, message = nil)
    response = { success: true }
    response[:message] = message if message.present?
    response[:data] = data if data.present?

    render json: response
  end

  # Helper method to format amount in Indian format with 2 decimal places
  def format_indian_amount(amount)
    return "0.00" if amount.nil? || amount.to_f == 0.0

    # Round to 2 decimal places first
    rounded_amount = amount.to_f.round(2)

    # Split into integer and decimal parts
    integer_part, decimal_part = sprintf("%.2f", rounded_amount).split('.')

    # Apply Indian numbering system (lakhs and crores)
    # Convert to string and reverse for easier processing
    reversed_digits = integer_part.reverse

    # Add commas in Indian format
    formatted = ""
    reversed_digits.chars.each_with_index do |digit, index|
      formatted += digit
      # Add comma after first 3 digits, then every 2 digits
      if index == 2
        formatted += "," if index < reversed_digits.length - 1
      elsif index > 2 && (index - 2) % 2 == 0
        formatted += "," if index < reversed_digits.length - 1
      end
    end

    # Reverse back and combine with decimal part
    "#{formatted.reverse}.#{decimal_part}"
  end
end