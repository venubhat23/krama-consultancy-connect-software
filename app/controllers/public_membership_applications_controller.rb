class PublicMembershipApplicationsController < ApplicationController
  skip_before_action :authenticate_user!
  skip_load_and_authorize_resource
  layout "public"

  before_action :set_application

  def show
  end

  def confirm_rsvp
    @application.confirm_rsvp! if @application.invited?
    redirect_to public_membership_application_path(@application.token)
  end

  def submit_feedback
    if @application.attended?
      @application.record_feedback!(rating: params[:feedback_rating], comment: params[:feedback_comment])
    end
    redirect_to public_membership_application_path(@application.token)
  end

  def confirm_interest
    @application.confirm_interest! if @application.invited?
    redirect_to public_membership_application_path(@application.token)
  end

  def submit_kyc
    if @application.invited? || @application.interested? || @application.feedback_collected?
      @application.submit_kyc!(kyc_params, documents: params.dig(:membership_application, :kyc_documents))
      redirect_to public_membership_application_path(@application.token)
    else
      redirect_to public_membership_application_path(@application.token), alert: "This application has already moved past the KYC step."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to public_membership_application_path(@application.token), alert: e.record.errors.full_messages.to_sentence
  end

  private

  def set_application
    @application = MembershipApplication.find_by!(token: params[:token])
  rescue ActiveRecord::RecordNotFound
    render plain: "We couldn't find that application link.", status: :not_found
  end

  def kyc_params
    params.require(:membership_application).permit(
      :company_name, :designation, :pan_number, :gst_number, :business_address
    )
  end
end
