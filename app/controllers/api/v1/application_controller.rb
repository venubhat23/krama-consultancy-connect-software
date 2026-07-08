class Api::V1::ApplicationController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  skip_load_and_authorize_resource
  before_action :set_default_format

  protected

  def set_default_format
    request.format = :json
  end

  def render_success(data = nil, message = 'Success', status = :ok)
    response = {
      success: true,
      message: message,
      data: data
    }
    render json: response, status: status
  end

  def render_error(message = 'Error occurred', errors = nil, status = :unprocessable_entity)
    response = {
      success: false,
      message: message,
      errors: errors
    }
    render json: response, status: status
  end

  def render_validation_errors(object)
    render_error(
      'Validation failed',
      object.errors.full_messages,
      :unprocessable_entity
    )
  end
end