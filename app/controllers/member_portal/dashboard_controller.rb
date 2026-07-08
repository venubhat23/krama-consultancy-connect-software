module MemberPortal
  class DashboardController < ApplicationController
    def index
      @announcements = Announcement.visible_to(current_user).recent_first.limit(5)
      @upcoming_events = Event.where(forum_id: current_user.forum_id, chapter_id: [current_user.chapter_id, nil])
                               .upcoming.limit(5)
      @my_open_tickets = current_user.support_tickets.where(status: :open).count
    end
  end
end
