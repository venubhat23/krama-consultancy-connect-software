module ForumPortal
  class DashboardController < ApplicationController
    def index
      @chapters = visible_chapters.order(:name)
      @member_count = visible_members.count
      @upcoming_events = Event.where(id: visible_event_ids).upcoming.limit(5)
      @open_tickets = SupportTicket.visible_to(current_user).where(status: :open).count
      @announcements = Announcement.visible_to(current_user).recent_first.limit(5)
    end

    private

    def visible_event_ids
      chapter_admin? ? Event.where(chapter_id: current_user.chapter_id).select(:id) : Event.where(forum_id: @current_forum.id).select(:id)
    end
  end
end
