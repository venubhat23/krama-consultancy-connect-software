class Api::V1::Mobile::SubAgentController < Api::V1::Mobile::BaseController
  before_action :authenticate_customer!
  before_action :validate_sub_agent_access

  # GET /api/v1/mobile/sub_agent/leads
  # Get leads submitted by the current sub_agent with comprehensive information
  def leads
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 20
    per_page = [per_page, 50].min # Limit to max 50 records per page
    status_filter = params[:status]
    product_filter = params[:product_category]
    search = params[:search]

    # Get leads created by this sub_agent with includes for better performance
    leads = Lead.where(affiliate_id: current_sub_agent.id)

    # Apply filters
    if status_filter.present?
      leads = leads.where(current_stage: status_filter)
    end

    if product_filter.present?
      leads = leads.where(product_category: product_filter)
    end

    if search.present?
      leads = leads.where("name ILIKE ? OR contact_number ILIKE ? OR email ILIKE ? OR lead_id ILIKE ?",
                         "%#{search}%", "%#{search}%", "%#{search}%", "%#{search}%")
    end

    # Get total count before pagination
    total_count = leads.count
    offset = (page - 1) * per_page

    # Order and paginate
    leads = leads.order(created_at: :desc)
                 .limit(per_page)
                 .offset(offset)

    render json: {
      success: true,
      data: {
        leads: leads.map do |lead|
          begin
            {
              id: lead.id,
              lead_id: lead.lead_id,
              name: lead.name,
              display_name: lead.name,
              first_name: lead.first_name,
              middle_name: lead.middle_name,
              last_name: lead.last_name,
              company_name: lead.company_name,
              contact_number: lead.contact_number,
              email: lead.email,
              current_stage: lead.current_stage,
              stage_display_name: lead.current_stage&.titleize || 'Unknown',
              product_category: lead.product_category,
              product_subcategory: lead.product_subcategory,
              product_interest: lead.product_interest,
              lead_source: lead.lead_source,
              customer_type: lead.customer_type,
              referred_by: lead.referred_by,
              referral_amount: lead.referral_amount || 0,
              birth_date: lead.birth_date,
              gender: lead.gender,
              marital_status: lead.marital_status,
              occupation: lead.occupation,
              annual_income: lead.annual_income,
              business_job: lead.business_job,
              pan_no: lead.pan_no,
              gst_no: lead.gst_no,
              height: lead.height,
              weight: lead.weight,
              address: lead.address,
              city: lead.city,
              state: lead.state,
              created_date: lead.created_date,
              stage_updated_at: lead.stage_updated_at,
              notes: lead.notes,
              is_converted: lead.converted_customer_id.present?,
              converted_customer_id: lead.converted_customer_id,
              policy_created_id: lead.policy_created_id,
              is_direct: lead.is_direct,
              is_branch_out: lead.is_branch_out,
              affiliate_id: lead.affiliate_id,
              ambassador_id: lead.ambassador_id,
              created_at: lead.created_at,
              updated_at: lead.updated_at,
              # Computed fields
              affiliate_name: current_sub_agent.display_name,
              ambassador_name: lead.ambassador_id.present? ? Distributor.find_by(id: lead.ambassador_id)&.display_name : nil,
              formatted_created_date: lead.created_date&.strftime('%d %b, %Y'),
              full_address: [lead.address, lead.city, lead.state].compact.reject(&:blank?).join(', ')
            }
          rescue => e
            Rails.logger.error "Error formatting lead #{lead.id}: #{e.message}"
            {
              id: lead.id,
              lead_id: lead.lead_id,
              name: lead.name,
              contact_number: lead.contact_number,
              email: lead.email,
              current_stage: lead.current_stage,
              error: "Error loading lead details"
            }
          end
        end,
        pagination: {
          current_page: page,
          total_pages: (total_count.to_f / per_page).ceil,
          total_count: total_count,
          per_page: per_page,
          has_next_page: page < (total_count.to_f / per_page).ceil,
          has_prev_page: page > 1
        },
        statistics: {
          total_leads: Lead.where(affiliate_id: current_sub_agent.id).count,
          converted_leads: Lead.where(affiliate_id: current_sub_agent.id, converted_customer_id: [1..Float::INFINITY]).count,
          pending_leads: Lead.where(affiliate_id: current_sub_agent.id, current_stage: ['consultation_scheduled', 'one_on_one', 'follow_up', 're_follow_up']).count,
          closed_leads: Lead.where(affiliate_id: current_sub_agent.id, current_stage: 'lead_closed').count
        }
      }
    }
  end

  private

  def validate_sub_agent_access
    unless current_user.is_a?(SubAgent)
      render json: {
        success: false,
        message: 'Access denied. Sub-agent account required.'
      }, status: :forbidden
    end
  end

  def current_sub_agent
    current_user # current_user is already a SubAgent object from authenticate_customer!
  end
end