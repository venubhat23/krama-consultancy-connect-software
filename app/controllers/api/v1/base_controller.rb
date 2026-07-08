class Api::V1::BaseController < ActionController::API
  include ExceptionHandler

  private

  # Serialize JSON response with message
  def json_response(object, status = :ok)
    render json: object, status: status
  end

  # Check for valid request token
  def authorize_request
    @current_user = (AuthorizeApiRequest.new(request.headers).call)[:user]
  end
end