module MemberPortal
  class EventsController < ApplicationController
    include ConfigurablePagination

    before_action :set_event, only: [:show, :register, :mark_attendance]

    def index
      events = Event.where(forum_id: current_user.forum_id, chapter_id: [current_user.chapter_id, nil])
                     .includes(:chapter).order(starts_at: :desc)
      @events = paginate_records(events)
      @registered_event_ids = current_user.event_registrations.where(event_id: @events.map(&:id)).pluck(:event_id).to_set
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

    private

    def set_event
      @event = Event.where(forum_id: current_user.forum_id, chapter_id: [current_user.chapter_id, nil]).find(params[:id])
    end
  end
end
