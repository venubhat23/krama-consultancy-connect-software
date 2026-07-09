module ForumPortal
  class OfficeDarshansController < ApplicationController
    include ConfigurablePagination

    before_action :set_event, only: [:show]

    def index
      @events = paginate_records(visible_scope.includes(:chapter, :created_by).order(starts_at: :desc))
    end

    def show
      @registrations = @event.event_registrations.includes(:user).order(:rsvp_status)
    end

    private

    def visible_scope
      base = Event.office_darshan.where(forum: @current_forum)
      chapter_admin? ? base.where(chapter_id: [current_user.chapter_id, nil]) : base
    end

    def set_event
      @event = visible_scope.find(params[:id])
    end
  end
end
