module MemberPortal
  class LeadsController < ApplicationController
    before_action :set_referral, only: [:show, :accept, :reject, :start_progress, :convert, :send_thanks]

    def index
      @referrals = current_user.received_referrals.includes(:referrer).recent_first
    end

    def show
      @whatsapp = ReferralThanksWhatsappMessage.for(@referral) if @referral.converted?
    end

    def accept
      @referral.accept!
      redirect_to member_portal_lead_path(@referral), notice: "Lead accepted."
    end

    def reject
      @referral.reject!(params[:note])
      redirect_to member_portal_leads_path, notice: "Lead declined."
    end

    def start_progress
      @referral.start_progress!
      redirect_to member_portal_lead_path(@referral), notice: "Marked as in progress."
    end

    def convert
      @referral.convert!
      redirect_to member_portal_lead_path(@referral), notice: "🎉 Marked as converted to business!"
    end

    def send_thanks
      @referral.mark_thanked!(params[:message])
      redirect_to member_portal_lead_path(@referral), notice: "Thanks recorded — tap the WhatsApp button to send it."
    end

    private

    def set_referral
      @referral = current_user.received_referrals.find(params[:id])
    end
  end
end
