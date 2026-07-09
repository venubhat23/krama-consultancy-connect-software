module MemberPortal
  class OfficeDarshansController < ApplicationController
    include ConfigurablePagination

    before_action :set_event, only: [:show, :rsvp, :mark_attendance, :invite_members, :toggle_attendance, :thank_attendee, :thank_all]
    before_action :ensure_organizer!, only: [:invite_members, :toggle_attendance, :thank_attendee, :thank_all]

    def index
      @invited_events = Event.office_darshan
                              .where(forum_id: current_user.forum_id, chapter_id: [current_user.chapter_id, nil])
                              .joins(:event_registrations).merge(EventRegistration.where(user_id: current_user.id))
                              .distinct.order(starts_at: :desc)
      @organized_events = Event.office_darshan.where(created_by: current_user).order(starts_at: :desc)
    end

    def new
      @event = Event.new
      @invitable_users = invitable_users_scope.order(:first_name)
    end

    def create
      @event = Event.new(event_params)
      @event.event_type = :office_darshan
      @event.forum_id = current_user.forum_id
      @event.created_by = current_user

      if @event.save
        invited_count = invite_members_for(@event)
        redirect_to member_portal_office_darshan_path(@event), notice: "Office Darshan announced — #{invited_count} member(s) invited."
      else
        @invitable_users = invitable_users_scope.order(:first_name)
        render :new, status: :unprocessable_entity
      end
    end

    def show
      @organizer = @event.created_by_id == current_user.id
      @registration = @event.event_registrations.find_by(user: current_user)

      if @organizer
        @registrations = @event.event_registrations.includes(:user).order(:rsvp_status)
        @invitable_users = invitable_users_scope
                              .where.not(id: @event.event_registrations.select(:user_id))
                              .order(:first_name)
      end
    end

    def rsvp
      attending = ActiveModel::Type::Boolean.new.cast(params[:attending])
      registration = @event.event_registrations.find_or_initialize_by(user: current_user)
      registration.rsvp_status = attending ? :going : :not_going
      registration.save!

      notice = attending ? "Great! You're marked as attending Office Darshan." : "Thanks for letting us know you can't make it."
      redirect_back fallback_location: member_portal_office_darshan_path(@event), notice: notice
    end

    def mark_attendance
      registration = @event.event_registrations.find_or_create_by!(user: current_user)
      registration.update!(attended: true)
      redirect_to member_portal_office_darshan_path(@event), notice: "Attendance marked. Thanks for coming!"
    end

    def invite_members
      invited_count = invite_members_for(@event)
      redirect_to member_portal_office_darshan_path(@event), notice: "#{invited_count} more member(s) invited."
    end

    def toggle_attendance
      registration = @event.event_registrations.find(params[:registration_id])
      registration.update!(attended: !registration.attended)
      redirect_to member_portal_office_darshan_path(@event), notice: "Attendance updated for #{registration.display_name}."
    end

    def thank_attendee
      registration = @event.event_registrations.find(params[:registration_id])
      registration.thank!
      redirect_to member_portal_office_darshan_path(@event), notice: "Thanked #{registration.display_name}."
    end

    def thank_all
      @event.event_registrations.where(attended: true, thanked: false).find_each(&:thank!)
      redirect_to member_portal_office_darshan_path(@event), notice: "Thank-you sent to everyone who attended."
    end

    private

    def set_event
      @event = Event.office_darshan
                     .where(forum_id: current_user.forum_id, chapter_id: [current_user.chapter_id, nil])
                     .find(params[:id])
    end

    def ensure_organizer!
      return if @event.created_by_id == current_user.id
      redirect_to member_portal_office_darshan_path(@event), alert: "Only the organizer can do that."
    end

    def invitable_users_scope
      User.where(forum_id: current_user.forum_id, user_type: 'member').where.not(id: current_user.id)
    end

    def invite_members_for(event)
      target_ids =
        if params[:audience] == "all"
          invitable_users_scope.pluck(:id)
        else
          Array(params[:member_ids]).reject(&:blank?)
        end

      count = 0
      User.where(id: target_ids).find_each do |member|
        registration = event.event_registrations.find_or_initialize_by(user: member)
        next if registration.persisted?

        registration.rsvp_status = :invited
        registration.invited_by = current_user
        registration.save!
        count += 1
      end
      count
    end

    def event_params
      params.require(:event).permit(:title, :description, :starts_at, :venue)
    end
  end
end
