class Api::V1::AuthenticationController < Api::V1::BaseController
  # POST /api/v1/auth/login
  def login
    authenticate_user
    return if performed? # Stop if already rendered (user not found)

    if @user&.valid_password?(user_params[:password])
      token = JwtService.encode(user_id: @user.id)
      time = Time.current + 24.hours.to_i
      render json: {
        success: true,
        message: 'Login successful',
        data: {
          token: token,
          exp: time.strftime("%m-%d-%Y %H:%M"),
          user: user_response(@user)
        }
      }, status: :ok
    else
      render json: {
        success: false,
        message: Message.invalid_credentials
      }, status: :unauthorized
    end
  end

  # POST /api/v1/auth/register
  def register
    user = User.create!(registration_params)
    if user
      token = JwtService.encode(user_id: user.id)
      time = Time.current + 24.hours.to_i
      render json: {
        success: true,
        message: Message.account_created,
        data: {
          token: token,
          exp: time.strftime("%m-%d-%Y %H:%M"),
          user: user_response(user)
        }
      }, status: :created
    else
      render json: {
        success: false,
        message: Message.account_not_created
      }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      success: false,
      message: 'Validation failed',
      errors: e.record.errors.full_messages
    }, status: :unprocessable_entity
  end

  # POST /api/v1/auth/forgot_password
  def forgot_password
    user = User.find_by(email: forgot_password_params[:email])

    if user
      user.send_reset_password_instructions
      render json: {
        success: true,
        message: 'Password reset instructions have been sent to your email'
      }, status: :ok
    else
      render json: {
        success: false,
        message: 'Email not found'
      }, status: :not_found
    end
  end

  # POST /api/v1/auth/reset_password
  def reset_password
    user = User.reset_password_by_token(reset_password_params)

    if user.errors.empty?
      render json: {
        success: true,
        message: 'Password has been reset successfully'
      }, status: :ok
    else
      render json: {
        success: false,
        message: 'Failed to reset password',
        errors: user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  # Strong parameters for login
  def user_params
    params.permit(:email, :password)
  end

  # Strong parameters for registration
  def registration_params
    permitted_params = params.permit(
      :first_name, :last_name, :email, :password, :password_confirmation,
      :mobile, :user_type, :role, :address, :city, :state, :pan_number,
      :gst_number, :date_of_birth, :gender, :occupation, :annual_income
    )

    # Set default role if not provided
    permitted_params[:role] ||= 'agent_role'
    permitted_params[:user_type] ||= 'agent'

    permitted_params.merge(status: true)
  end

  # Strong parameters for forgot password
  def forgot_password_params
    params.permit(:email)
  end

  # Strong parameters for reset password
  def reset_password_params
    params.permit(:reset_password_token, :password, :password_confirmation)
  end

  # Find user by email
  def authenticate_user
    @user = User.find_by(email: user_params[:email])
    unless @user
      render json: {
        success: false,
        message: Message.invalid_credentials
      }, status: :unauthorized
      return
    end
  end

  # Format user response
  def user_response(user)
    {
      id: user.id,
      first_name: user.first_name,
      last_name: user.last_name,
      full_name: user.full_name,
      email: user.email,
      mobile: user.mobile,
      user_type: user.user_type,
      role: user.role,
      status: user.status,
      address: user.address,
      city: user.city,
      state: user.state,
      pan_number: user.pan_number,
      gst_number: user.gst_number,
      date_of_birth: user.date_of_birth,
      gender: user.gender,
      occupation: user.occupation,
      annual_income: user.annual_income,
      created_at: user.created_at,
      updated_at: user.updated_at
    }
  end
end