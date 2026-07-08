class ForumRequestsController < ApplicationController
  skip_before_action :authenticate_user!
  skip_load_and_authorize_resource
  layout 'public'

  def new
    @forum_request = ForumRequest.new
  end

  def create
    @forum_request = ForumRequest.new(forum_request_params)
    if @forum_request.save
      redirect_to new_forum_request_path, notice: 'Thanks! Your request has been submitted for review.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def forum_request_params
    params.require(:forum_request).permit(:name, :email, :phone, :company_name, :message)
  end
end
