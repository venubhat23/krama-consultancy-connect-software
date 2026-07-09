module ForumPortal
  class LeadsController < ApplicationController
    def index
      @referrals = visible_referrals.includes(:referrer, :referred_user).recent_first
      @stats = {
        total: visible_referrals.count,
        pending: visible_referrals.pending.count,
        accepted: visible_referrals.accepted.count,
        in_progress: visible_referrals.in_progress.count,
        converted: visible_referrals.converted.count,
        rejected: visible_referrals.rejected.count
      }
    end

    private

    def visible_referrals
      base = Referral.where(forum: @current_forum)
      chapter_admin? ? base.where(chapter_id: current_user.chapter_id) : base
    end
  end
end
