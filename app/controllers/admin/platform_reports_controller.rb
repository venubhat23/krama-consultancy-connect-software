class Admin::PlatformReportsController < Admin::SuperAdminBaseController
  def index
    @forums = Forum.includes(:business_plan).order(:name)
    forum_ids = @forums.map(&:id)
    @chapter_counts = Chapter.where(forum_id: forum_ids).group(:forum_id).count
    @member_counts = User.where(forum_id: forum_ids, user_type: 'member').group(:forum_id).count
    @admin_by_forum = User.where(forum_id: forum_ids, user_type: 'forum_admin').index_by(&:forum_id)

    @revenue_rows = BusinessPlan.ordered.map do |plan|
      active_count = plan.forums.active.count
      { plan: plan, active_forums: active_count, mrr: active_count * plan.price }
    end
    @total_mrr = @revenue_rows.sum { |r| r[:mrr] }

    @request_status_counts = ForumRequest.group(:status).count
    @ticket_status_counts = SupportTicket.group(:status).count
  end
end
