module MemberPortal
  class ReferralsController < ApplicationController
    def new
      @referral = Referral.new
    end

    def create
      referred_user = referable_users.find(params[:referral][:referred_user_id])
      @referral = Referral.new(referral_params)
      @referral.referrer = current_user
      @referral.referred_user = referred_user

      if @referral.save
        redirect_to member_portal_leads_path, notice: "Referral sent to #{referred_user.full_name}."
      else
        @selected_user = referred_user
        render :new, status: :unprocessable_entity
      end
    end

    def search_members
      q = params[:q].to_s.strip
      members = referable_users
      if q.present?
        members = members.where(
          "first_name ILIKE :q OR last_name ILIKE :q OR email ILIKE :q OR company_name ILIKE :q",
          q: "%#{q}%"
        )
      end

      render json: members.limit(15).map { |m| member_payload(m) }
    end

    private

    def referable_users
      User.where(forum_id: current_user.forum_id).where.not(id: current_user.id)
    end

    def member_payload(member)
      {
        id: member.id,
        name: member.full_name,
        chapter: member.chapter&.name,
        company_name: member.company_name,
        designation: member.designation,
        business_category: member.business_category,
        speciality: member.speciality,
        nature_of_business: member.nature_of_business,
        mobile: member.mobile
      }
    end

    def referral_params
      params.require(:referral).permit(:business_context, :contact_name, :contact_phone)
    end
  end
end
