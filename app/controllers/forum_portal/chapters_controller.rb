module ForumPortal
  class ChaptersController < ApplicationController
    include ConfigurablePagination

    before_action :ensure_forum_admin, only: [:new, :create, :destroy]
    before_action :set_chapter, only: [:show, :edit, :update, :destroy]

    def index
      chapters = visible_chapters.includes(:forum)
      chapter_ids = chapters.map(&:id)
      @member_counts = User.where(chapter_id: chapter_ids, user_type: 'member').group(:chapter_id).count
      @chapters = paginate_records(chapters.order(:name))
    end

    def show
      @members = @chapter.users.where(user_type: 'member').order(:first_name)
      @admin = @chapter.admin
    end

    def new
      @chapter = @current_forum.chapters.new
    end

    def create
      @chapter = @current_forum.chapters.new(chapter_params)
      if @chapter.save
        redirect_to forum_portal_chapters_path, notice: "Chapter '#{@chapter.name}' created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @chapter.update(chapter_params)
        redirect_to forum_portal_chapter_path(@chapter), notice: "Chapter '#{@chapter.name}' updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @chapter.users.exists?
        redirect_to forum_portal_chapters_path, alert: "Can't delete '#{@chapter.name}' while it still has members."
      else
        @chapter.destroy
        redirect_to forum_portal_chapters_path, notice: "Chapter '#{@chapter.name}' deleted."
      end
    end

    private

    def ensure_forum_admin
      unless current_user.forum_admin?
        redirect_to forum_portal_chapters_path, alert: 'Only the forum admin can manage chapters.'
      end
    end

    def set_chapter
      @chapter = visible_chapters.find(params[:id])
    end

    def chapter_params
      params.require(:chapter).permit(:name, :status)
    end
  end
end
