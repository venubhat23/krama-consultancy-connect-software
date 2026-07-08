module ForumPortal
  class MembersController < ApplicationController
    include ConfigurablePagination

    before_action :set_member, only: [:show, :edit, :update, :destroy]

    def index
      members = visible_members_and_chapter_admins.includes(:chapter).order(:first_name)
      @members = paginate_records(members)
    end

    def show
    end

    def new
      @member = User.new
      @chapters = visible_chapters.order(:name)
    end

    def create
      @member = User.new(member_params)
      @member.user_type = allowed_user_type(params.dig(:user, :user_type))
      @member.forum = @current_forum
      @member.status = true

      if @member.save
        redirect_to forum_portal_members_path, notice: "#{@member.full_name} added as #{@member.user_type.humanize}."
      else
        @chapters = visible_chapters.order(:name)
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @chapters = visible_chapters.order(:name)
    end

    def update
      if @member.update(member_params)
        redirect_to forum_portal_member_path(@member), notice: "#{@member.full_name} updated."
      else
        @chapters = visible_chapters.order(:name)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @member.destroy
      redirect_to forum_portal_members_path, notice: "#{@member.full_name} removed."
    end

    private

    def visible_members_and_chapter_admins
      base = User.where(forum_id: @current_forum.id, user_type: ['member', 'chapter_admin'])
      chapter_admin? ? base.where(chapter_id: current_user.chapter_id) : base
    end

    def set_member
      @member = visible_members_and_chapter_admins.find(params[:id])
    end

    # chapter_admin may only ever create plain members; forum_admin may also promote to chapter_admin.
    def allowed_user_type(requested)
      return 'member' if chapter_admin?
      %w[member chapter_admin].include?(requested) ? requested : 'member'
    end

    def member_params
      params.require(:user).permit(:first_name, :last_name, :email, :mobile, :chapter_id, :password, :password_confirmation)
    end
  end
end
