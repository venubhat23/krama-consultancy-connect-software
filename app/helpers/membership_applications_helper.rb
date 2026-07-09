module MembershipApplicationsHelper
  STATUS_COLORS = {
    "invited" => "secondary",
    "confirmed" => "info",
    "attended" => "info",
    "feedback_collected" => "info",
    "interested" => "primary",
    "kyc_submitted" => "warning",
    "under_review" => "warning",
    "approved" => "success",
    "paid" => "success",
    "member" => "success",
    "rejected" => "danger"
  }.freeze

  def membership_status_color(status)
    STATUS_COLORS[status.to_s] || "secondary"
  end
end
