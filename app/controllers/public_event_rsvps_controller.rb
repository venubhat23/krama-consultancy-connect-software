class PublicEventRsvpsController < ApplicationController
  skip_before_action :authenticate_user!
  skip_load_and_authorize_resource
  layout "public"

  before_action :set_registration

  def show
  end

  def respond
    if %w[going not_going].include?(params[:rsvp_status])
      @registration.update!(rsvp_status: params[:rsvp_status])
    end
    redirect_to public_event_rsvp_path(@registration.token)
  end

  private

  def set_registration
    @registration = EventRegistration.find_by!(token: params[:token])
  rescue ActiveRecord::RecordNotFound
    render plain: "We couldn't find that invite link.", status: :not_found
  end
end
