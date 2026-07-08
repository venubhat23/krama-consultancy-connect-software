module MemberPortal
  class EventsController < ApplicationController
    include ConfigurablePagination

    before_action :set_event, only: [:show, :register, :mark_attendance, :rsvp]

    def index
      events = Event.where(forum_id: current_user.forum_id, chapter_id: [current_user.chapter_id, nil])
                     .includes(:chapter).order(starts_at: :desc)
      @events = paginate_records(events)
      @registrations_by_event_id = current_user.event_registrations
                                                .where(event_id: @events.map(&:id))
                                                .index_by(&:event_id)
    end

    def show
      @registration = @event.event_registrations.find_by(user: current_user)
    end

    def register
      @event.event_registrations.find_or_create_by!(user: current_user)
      redirect_to member_portal_event_path(@event), notice: "You're registered for #{@event.title}."
    end

    def mark_attendance
      registration = @event.event_registrations.find_or_create_by!(user: current_user)
      registration.update!(attended: true)
      redirect_to member_portal_event_path(@event), notice: 'Attendance marked. Thanks for checking in!'
    end

    def rsvp
      attending = ActiveModel::Type::Boolean.new.cast(params[:attending])
      registration = @event.event_registrations.find_or_initialize_by(user: current_user)
      registration.rsvp_status = attending ? :going : :not_going
      registration.save!

      notice = attending ? "Great! You're marked as attending #{@event.title}." : "Thanks for letting us know you can't make it to #{@event.title}."
      redirect_back fallback_location: member_portal_dashboard_path, notice: notice
    end

    private

    def set_event
      @event = Event.where(forum_id: current_user.forum_id, chapter_id: [current_user.chapter_id, nil]).find(params[:id])
    end
  end
end
