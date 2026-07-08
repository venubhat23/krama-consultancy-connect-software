class Admin::PlatformDashboardController < Admin::SuperAdminBaseController
  def index
    @total_forums = Forum.count
    @active_forums = Forum.active.count
    @suspended_forums = Forum.suspended.count
    @total_chapters = Chapter.count
    @total_members = User.where(user_type: 'member').count
    @mrr = Forum.active.joins(:business_plan).sum('business_plans.price')
    @pending_requests = ForumRequest.pending.count
    @open_tickets = SupportTicket.open.count

    @forums_by_plan = Forum.joins(:business_plan).group('business_plans.name').count
    @member_growth = User.where(user_type: 'member').group_by_month(:created_at, last: 6).count
    @forum_growth = Forum.group_by_month(:created_at, last: 6).count

    @recent_requests = ForumRequest.recent_first.limit(5)
    @recent_tickets = SupportTicket.with_list_includes.where(status: :open).recent_first.limit(5)
  end
end
