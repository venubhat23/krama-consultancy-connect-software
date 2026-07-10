class Admin::ForumsController < Admin::SuperAdminBaseController
  include ConfigurablePagination

  before_action :set_forum, only: [:show, :edit, :update, :destroy, :suspend, :activate, :update_plan, :force_logout_admin]

  def index
    forums = Forum.includes(:business_plan).order(:name)
    @forums = paginate_records(forums)

    forum_ids = @forums.map(&:id)
    @chapter_counts = Chapter.where(forum_id: forum_ids).group(:forum_id).count
    @member_counts = User.where(forum_id: forum_ids, user_type: 'member').group(:forum_id).count
    @admin_by_forum = User.where(forum_id: forum_ids, user_type: 'forum_admin').index_by(&:forum_id)
  end

  def show
    @chapters = @forum.chapters.includes(:users).order(:name)
    @admin = @forum.admin
    @members = paginate_records(@forum.users.where(user_type: 'member').order(:first_name, :last_name))
  end

  def new
    @forum = Forum.new
    @business_plans = BusinessPlan.active.ordered
  end

  def create
    business_plan = BusinessPlan.find(params[:forum][:business_plan_id])

    forum = Forum.provision!(
      name: params[:forum][:name],
      business_plan: business_plan,
      admin_attrs: admin_attrs_from_params
    )
    redirect_to admin_forum_path(forum), notice: "#{forum.name} created with admin login #{forum.admin.email}."
  rescue ActiveRecord::RecordInvalid => e
    @forum = Forum.new(name: params[:forum][:name])
    @business_plans = BusinessPlan.active.ordered
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :new, status: :unprocessable_entity
  end

  def edit
    @business_plans = BusinessPlan.active.ordered
  end

  def update
    if @forum.update(forum_params)
      redirect_to admin_forum_path(@forum), notice: "#{@forum.name} updated."
    else
      @business_plans = BusinessPlan.active.ordered
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @forum.chapters.exists? || @forum.users.exists?
      redirect_to admin_forum_path(@forum), alert: "Can't delete #{@forum.name} while it still has chapters or members. Suspend it instead."
    else
      @forum.destroy
      redirect_to admin_forums_path, notice: "#{@forum.name} deleted."
    end
  end

  def suspend
    @forum.update!(status: :suspended, suspended_at: Time.current)
    @forum.admin&.force_logout!
    redirect_to admin_forum_path(@forum), notice: "#{@forum.name} suspended."
  end

  def activate
    @forum.update!(status: :active, suspended_at: nil)
    redirect_to admin_forum_path(@forum), notice: "#{@forum.name} activated."
  end

  def update_plan
    plan = BusinessPlan.find(params[:business_plan_id])
    @forum.update!(business_plan: plan)
    redirect_to admin_forum_path(@forum), notice: "#{@forum.name} moved to the #{plan.name} plan."
  end

  def force_logout_admin
    @forum.admin&.force_logout!
    redirect_to admin_forum_path(@forum), notice: "#{@forum.name}'s admin has been signed out of all sessions."
  end

  private

  def set_forum
    @forum = Forum.find(params[:id])
  end

  def forum_params
    params.require(:forum).permit(:name, :business_plan_id)
  end

  def admin_attrs_from_params
    {
      email: params[:admin][:email],
      password: params[:admin][:password],
      password_confirmation: params[:admin][:password],
      first_name: params[:admin][:first_name],
      last_name: params[:admin][:last_name],
      mobile: params[:admin][:mobile]
    }
  end
end
