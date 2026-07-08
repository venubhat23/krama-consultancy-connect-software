class Admin::PlatformAnalyticsController < Admin::SuperAdminBaseController
  def index
    forums = Forum.includes(:business_plan).order(:name)
    member_counts = User.where(user_type: 'member').group(:forum_id).count
    @members_per_forum = forums.to_h { |f| [f.name, member_counts[f.id] || 0] }

    @forums_by_plan = BusinessPlan.ordered.to_h { |p| [p.name, p.forums.count] }
    @revenue_by_plan = BusinessPlan.ordered.to_h { |p| [p.name, p.forums.active.count * p.price] }

    @forum_status_distribution = Forum.group(:status).count.transform_keys { |k| k || "unknown" }
    @ticket_status_distribution = SupportTicket.group(:status).count
    @ticket_priority_distribution = SupportTicket.group(:priority).count
    @announcement_audience_distribution = Announcement.group(:audience).count

    @total_registrations = EventRegistration.count
    @total_attended = EventRegistration.where(attended: true).count
    @attendance_rate = @total_registrations.zero? ? 0 : ((@total_attended.to_f / @total_registrations) * 100).round(1)

    @signups_by_month = User.where(user_type: 'member').group_by_month(:created_at, last: 12).count
  end
end
