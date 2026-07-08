module ForumPortal
  class EventsController < ApplicationController
    include ConfigurablePagination

    before_action :set_event, only: [:show, :edit, :update, :destroy, :toggle_attendance, :invite_guest]

    def index
      events = visible_scope.includes(:chapter).order(starts_at: :desc)
      @events = paginate_records(events)
    end

    def show
      @registrations = @event.event_registrations.includes(:user).order("users.first_name")
    end

    def new
      @event = Event.new
      @chapters = visible_chapters.order(:name)
    end

    def create
      @event = @current_forum.events.new(event_params)
      @event.chapter_id = current_user.chapter_id if chapter_admin?

      if @event.save
        redirect_to forum_portal_events_path, notice: "Event '#{@event.title}' created."
      else
        @chapters = visible_chapters.order(:name)
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @chapters = visible_chapters.order(:name)
    end

    def update
      if @event.update(event_params)
        redirect_to forum_portal_event_path(@event), notice: "Event '#{@event.title}' updated."
      else
        @chapters = visible_chapters.order(:name)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @event.destroy
      redirect_to forum_portal_events_path, notice: "Event '#{@event.title}' deleted."
    end

    def toggle_attendance
      registration = @event.event_registrations.find(params[:registration_id])
      registration.update!(attended: !registration.attended)
      redirect_to forum_portal_event_path(@event), notice: "Attendance updated for #{registration.display_name}."
    end

    def invite_guest
      registration = @event.event_registrations.new(guest_params)
      registration.invited_by = current_user
      registration.rsvp_status = :going

      if registration.save
        redirect_to forum_portal_event_path(@event), notice: "#{registration.guest_name} invited as a guest."
      else
        redirect_to forum_portal_event_path(@event), alert: registration.errors.full_messages.to_sentence
      end
    end

    private

    def visible_scope
      chapter_admin? ? Event.where(forum: @current_forum, chapter_id: [current_user.chapter_id, nil]) : Event.where(forum: @current_forum)
    end

    def set_event
      @event = visible_scope.find(params[:id])
    end

    def event_params
      params.require(:event).permit(:title, :description, :event_type, :starts_at, :venue, :chapter_id)
    end

    def guest_params
      params.require(:registration).permit(:guest_name, :guest_email)
    end
  end
end
