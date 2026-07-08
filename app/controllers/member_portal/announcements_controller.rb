module MemberPortal
  class AnnouncementsController < ApplicationController
    include ConfigurablePagination

    def index
      announcements = Announcement.visible_to(current_user).includes(:forum, :chapter, :created_by).recent_first
      @announcements = paginate_records(announcements)
    end
  end
end
