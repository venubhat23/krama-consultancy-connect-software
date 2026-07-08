module ForumPortal
  class AnnouncementsController < ApplicationController
    include ConfigurablePagination

    before_action :set_announcement, only: [:destroy]

    def index
      announcements = visible_scope.includes(:chapter, :target_user, :created_by).recent_first
      @announcements = paginate_records(announcements)
    end

    def new
      @announcement = Announcement.new
      load_targeting_options
    end

    def create
      @announcement = current_user.created_announcements.new(announcement_params)
      @announcement.forum = @current_forum

      if @announcement.save
        redirect_to forum_portal_announcements_path, notice: "Announcement '#{@announcement.title}' posted."
      else
        load_targeting_options
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      @announcement.destroy
      redirect_to forum_portal_announcements_path, notice: "Announcement '#{@announcement.title}' removed."
    end

    private

    def visible_scope
      Announcement.where(forum: @current_forum)
    end

    def set_announcement
      @announcement = visible_scope.find(params[:id])
    end

    def load_targeting_options
      @chapters = visible_chapters.order(:name)
      @members = visible_members.order(:first_name)
    end

    def announcement_params
      permitted = params.require(:announcement).permit(:title, :body, :audience, :chapter_id, :target_user_id)

      # Nobody in this portal may broadcast platform-wide — that's super_admin only.
      permitted[:audience] = 'specific_forum' if permitted[:audience] == 'everyone'

      # chapter_admin can only ever target their own chapter or its members.
      if chapter_admin?
        permitted[:audience] = 'specific_chapter' if permitted[:audience] == 'specific_forum'
        permitted[:chapter_id] = current_user.chapter_id if permitted[:audience] == 'specific_chapter'
      end

      permitted
    end
  end
end
