class Admin::AnnouncementsController < Admin::SuperAdminBaseController
  include ConfigurablePagination

  before_action :set_announcement, only: [:show, :edit, :update, :destroy, :publish]

  def index
    announcements = Announcement.includes(:forum, :chapter, :target_user, :created_by).recent_first
    @announcements = paginate_records(announcements)
  end

  def show
  end

  def new
    @announcement = Announcement.new
    load_targeting_options
  end

  def create
    @announcement = current_user.created_announcements.new(announcement_params)
    if @announcement.save
      redirect_to admin_platform_announcements_path, notice: "Announcement '#{@announcement.title}' published."
    else
      load_targeting_options
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_targeting_options
  end

  def update
    if @announcement.update(announcement_params)
      redirect_to admin_platform_announcements_path, notice: "Announcement '#{@announcement.title}' updated."
    else
      load_targeting_options
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @announcement.destroy
    redirect_to admin_platform_announcements_path, notice: "Announcement '#{@announcement.title}' removed."
  end

  def publish
    @announcement.update!(published_at: Time.current)
    redirect_to admin_platform_announcements_path, notice: "Announcement '#{@announcement.title}' published."
  end

  private

  def set_announcement
    @announcement = Announcement.find(params[:id])
  end

  def load_targeting_options
    @forums = Forum.order(:name)
    @chapters = Chapter.includes(:forum).order(:name)
    @members = User.where(user_type: 'member').order(:first_name)
  end

  def announcement_params
    params.require(:announcement).permit(:title, :body, :audience, :forum_id, :chapter_id, :target_user_id, :published_at)
  end
end
