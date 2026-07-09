module ForumPortal
  class MembershipApplicationsController < ApplicationController
    include ConfigurablePagination

    before_action :set_application, only: [
      :show, :confirm_rsvp, :mark_attended, :record_feedback, :send_join_invite,
      :start_review, :approve, :reject, :mark_paid, :convert_to_member
    ]

    def index
      scope = visible_applications.includes(:chapter, :event, :invited_by).recent_first
      scope = scope.where(status: params[:status]) if params[:status].present? && MembershipApplication.statuses.key?(params[:status])
      @status_counts = visible_applications.group(:status).count
      @applications = paginate_records(scope)
    end

    def new
      @application = MembershipApplication.new
      @chapters = visible_chapters.order(:name)
      @events = @current_forum.events.order(starts_at: :desc)
    end

    def create
      @application = MembershipApplication.new(application_params)
      @application.forum = @current_forum
      @application.invited_by = current_user
      @application.chapter_id = current_user.chapter_id if chapter_admin?

      if @application.save
        redirect_to forum_portal_membership_application_path(@application), notice: "#{@application.name} invited. Send the WhatsApp link to get them started."
      else
        @chapters = visible_chapters.order(:name)
        @events = @current_forum.events.order(starts_at: :desc)
        render :new, status: :unprocessable_entity
      end
    end

    def show
      @whatsapp = MembershipWhatsappMessage.for(@application)
    end

    def confirm_rsvp
      @application.confirm_rsvp!
      redirect_to forum_portal_membership_application_path(@application), notice: "Marked as confirmed."
    end

    def mark_attended
      @application.mark_attended!
      redirect_to forum_portal_membership_application_path(@application), notice: "Marked as attended."
    end

    def record_feedback
      @application.record_feedback!(rating: params[:feedback_rating], comment: params[:feedback_comment])
      redirect_to forum_portal_membership_application_path(@application), notice: "Feedback recorded."
    end

    def send_join_invite
      @application.send_join_invite!
      redirect_to forum_portal_membership_application_path(@application), notice: "Marked as invited to join — send them the WhatsApp link."
    end

    def start_review
      @application.start_review!
      redirect_to forum_portal_membership_application_path(@application), notice: "Now under review."
    end

    def approve
      @application.approve!(reviewer: current_user, payment_instructions: params[:payment_instructions])
      redirect_to forum_portal_membership_application_path(@application), notice: "Application approved."
    end

    def reject
      if params[:review_note].blank?
        redirect_to forum_portal_membership_application_path(@application), alert: "Please provide a reason for rejecting."
        return
      end
      @application.reject!(reviewer: current_user, note: params[:review_note])
      redirect_to forum_portal_membership_application_path(@application), notice: "Application rejected."
    end

    def mark_paid
      @application.mark_paid!
      redirect_to forum_portal_membership_application_path(@application), notice: "Marked as paid."
    end

    def convert_to_member
      temp_password = @application.convert_to_member!
      redirect_to forum_portal_membership_application_path(@application),
        notice: "#{@application.name} is now a member! Temporary login — email: #{@application.email}, password: #{temp_password}. Share this with them securely."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to forum_portal_membership_application_path(@application), alert: e.record.errors.full_messages.to_sentence
    end

    private

    def visible_applications
      base = MembershipApplication.where(forum_id: @current_forum.id)
      chapter_admin? ? base.where(chapter_id: current_user.chapter_id) : base
    end

    def set_application
      @application = visible_applications.find(params[:id])
    end

    def application_params
      params.require(:membership_application).permit(:name, :email, :phone, :company_name, :chapter_id, :event_id)
    end
  end
end
