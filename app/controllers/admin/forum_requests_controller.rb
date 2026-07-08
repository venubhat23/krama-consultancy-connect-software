class Admin::ForumRequestsController < Admin::SuperAdminBaseController
  include ConfigurablePagination

  before_action :set_forum_request, only: [:show, :approve, :reject]

  def index
    requests = ForumRequest.includes(:business_plan, :forum, :reviewed_by).recent_first
    @forum_requests = paginate_records(requests)
  end

  def show
    @business_plans = BusinessPlan.active.ordered
  end

  def approve
    plan_key = params[:business_plan_id].presence
    business_plan = plan_key ? BusinessPlan.find(plan_key) : BusinessPlan.find_by(key: SystemSetting.default_business_plan_key) || BusinessPlan.active.ordered.first

    forum = Forum.provision!(
      name: @forum_request.company_name,
      business_plan: business_plan,
      admin_attrs: {
        email: params[:admin_email].presence || @forum_request.email,
        password: params[:admin_password],
        password_confirmation: params[:admin_password],
        first_name: @forum_request.name.split.first || @forum_request.name,
        last_name: @forum_request.name.split[1..].join(' ').presence || @forum_request.name,
        mobile: @forum_request.phone
      }
    )
    @forum_request.update!(status: :approved, forum: forum, reviewed_by: current_user)
    redirect_to admin_forum_request_path(@forum_request),
      notice: "#{@forum_request.company_name} approved and forum created with admin login #{forum.admin.email}."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_forum_request_path(@forum_request), alert: e.record.errors.full_messages.to_sentence
  end

  def reject
    @forum_request.update!(status: :rejected, review_note: params[:review_note], reviewed_by: current_user)
    redirect_to admin_forum_requests_path, notice: "Request from #{@forum_request.company_name} rejected."
  end

  private

  def set_forum_request
    @forum_request = ForumRequest.find(params[:id])
  end
end
