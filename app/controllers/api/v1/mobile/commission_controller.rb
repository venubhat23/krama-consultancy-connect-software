class Api::V1::Mobile::CommissionController < Api::V1::Mobile::BaseController
  before_action :authenticate_customer!
  before_action :validate_sub_agent_access

  # GET /api/v1/mobile/commission/breakdown
  def breakdown
    begin
      # Get commission summary for current sub-agent
      commission_summary = calculate_commission_summary
      recent_payouts = get_recent_commission_payouts

      response_data = {
        status: 'success',
        data: {
          commission_summary: commission_summary,
          recent_payouts: recent_payouts
        },
        timestamp: Time.current.iso8601
      }

      render json: response_data, status: :ok

    rescue => e
      Rails.logger.error "Commission breakdown API error: #{e.message}"
      render json: {
        status: 'error',
        message: 'Unable to fetch commission breakdown',
        error: e.message
      }, status: :internal_server_error
    end
  end

  # GET /api/v1/mobile/commission/summary
  def summary
    begin
      summary_data = calculate_commission_summary

      render json: {
        status: 'success',
        data: summary_data,
        timestamp: Time.current.iso8601
      }, status: :ok

    rescue => e
      Rails.logger.error "Commission summary API error: #{e.message}"
      render json: {
        status: 'error',
        message: 'Unable to fetch commission summary',
        error: e.message
      }, status: :internal_server_error
    end
  end

  # GET /api/v1/mobile/commission/history
  def history
    begin
      page = params[:page]&.to_i || 1
      per_page = params[:per_page]&.to_i || 10
      per_page = [per_page, 50].min # Limit to max 50 records per page
      offset = (page - 1) * per_page

      # Get all payouts for current sub-agent
      all_payouts = get_all_sub_agent_payouts
      total_count = all_payouts.count

      # Get paginated commission history
      payouts = all_payouts
                .order(payout_date: :desc, created_at: :desc)
                .limit(per_page)
                .offset(offset)

      formatted_payouts = payouts.map { |payout| format_payout_data(payout) }

      total_pages = (total_count.to_f / per_page).ceil

      render json: {
        status: 'success',
        data: {
          payouts: formatted_payouts,
          pagination: {
            current_page: page,
            per_page: per_page,
            total_pages: total_pages,
            total_count: total_count,
            has_next_page: page < total_pages,
            has_prev_page: page > 1
          }
        },
        timestamp: Time.current.iso8601
      }, status: :ok

    rescue => e
      Rails.logger.error "Commission history API error: #{e.message}"
      render json: {
        status: 'error',
        message: 'Unable to fetch commission history',
        error: e.message
      }, status: :internal_server_error
    end
  end

  # GET /api/v1/mobile/commission/stats
  def stats
    begin
      current_year = Date.current.year
      current_month = Date.current.month

      # Monthly stats for current year
      monthly_stats = (1..12).map do |month|
        start_date = Date.new(current_year, month, 1)
        end_date = start_date.end_of_month

        monthly_payouts = get_sub_agent_payouts_for_period(start_date, end_date)

        {
          month: month,
          month_name: Date::MONTHNAMES[month],
          total_earned: monthly_payouts.sum(:payout_amount),
          paid_amount: monthly_payouts.paid.sum(:payout_amount),
          pending_amount: monthly_payouts.pending.sum(:payout_amount),
          processing_amount: monthly_payouts.processing.sum(:payout_amount),
          payout_count: monthly_payouts.count
        }
      end

      # Year-to-date totals
      ytd_start = Date.new(current_year, 1, 1)
      ytd_payouts = get_sub_agent_payouts_for_period(ytd_start, Date.current)

      ytd_stats = {
        total_earned: ytd_payouts.sum(:payout_amount),
        paid_amount: ytd_payouts.paid.sum(:payout_amount),
        pending_amount: ytd_payouts.pending.sum(:payout_amount),
        processing_amount: ytd_payouts.processing.sum(:payout_amount),
        total_policies: ytd_payouts.count
      }

      render json: {
        status: 'success',
        data: {
          monthly_stats: monthly_stats,
          ytd_stats: ytd_stats,
          year: current_year
        },
        timestamp: Time.current.iso8601
      }, status: :ok

    rescue => e
      Rails.logger.error "Commission stats API error: #{e.message}"
      render json: {
        status: 'error',
        message: 'Unable to fetch commission stats',
        error: e.message
      }, status: :internal_server_error
    end
  end

  private

  def validate_sub_agent_access
    unless current_user.is_a?(SubAgent) || current_user.is_a?(User)
      render json: {
        status: 'error',
        message: 'Access denied. Agent or sub-agent account required.'
      }, status: :forbidden
    end
  end

  def get_current_sub_agent
    current_user # current_user is already a SubAgent object from authenticate_customer!
  end

  def calculate_commission_summary
    # Load all payouts into memory so we can call model methods for gross/tds amounts
    all_payouts = get_all_sub_agent_payouts.to_a

    total_gross      = all_payouts.sum { |p| p.gross_commission_amount.to_f }
    total_tds        = all_payouts.sum { |p| p.tds_amount.to_f }
    total_net        = total_gross - total_tds

    paid_net         = all_payouts.select(&:paid?).sum       { |p| p.net_amount.to_f }
    pending_net      = all_payouts.select(&:pending?).sum    { |p| p.net_amount.to_f }
    processing_net   = all_payouts.select(&:processing?).sum { |p| p.net_amount.to_f }

    {
      commission_earned:     format_currency(total_gross),
      commission_earned_raw: total_gross.round(2).to_s,
      total_tds_deducted:    format_currency(total_tds),
      total_tds_deducted_raw: total_tds.round(2).to_s,
      total_earned:          format_currency(total_net),
      total_earned_raw:      total_net.round(2).to_s,
      paid:                  format_currency(paid_net),
      paid_raw:              paid_net.round(2).to_s,
      pending:               format_currency(pending_net),
      pending_raw:           pending_net.round(2).to_s,
      processing:            format_currency(processing_net),
      processing_raw:        processing_net.round(2).to_s,
      total_policies:        all_payouts.count,
      active_policies:       all_payouts.count { |p| p.status != 'cancelled' }
    }
  end

  def get_recent_commission_payouts(limit = 7)
    recent_payouts = get_all_sub_agent_payouts
                      .order(payout_date: :desc, created_at: :desc)
                      .limit(limit)

    recent_payouts.map { |payout| format_payout_data(payout) }
  end

  def get_all_sub_agent_payouts
    user = current_user
    return CommissionPayout.none unless user

    if user.is_a?(SubAgent)
      # Sub-agents/affiliates receive 'affiliate' payouts.
      # other_insurances has no sub_agent_id column so it is excluded from the join.
      CommissionPayout.where(
        policy_type: ['health', 'life', 'motor'],
        payout_to: 'affiliate'
      ).joins(
        "LEFT JOIN health_insurances ON commission_payouts.policy_type = 'health' AND commission_payouts.policy_id = health_insurances.id
         LEFT JOIN life_insurances ON commission_payouts.policy_type = 'life' AND commission_payouts.policy_id = life_insurances.id
         LEFT JOIN motor_insurances ON commission_payouts.policy_type = 'motor' AND commission_payouts.policy_id = motor_insurances.id"
      ).where(
        "COALESCE(health_insurances.sub_agent_id, life_insurances.sub_agent_id, motor_insurances.sub_agent_id) = ?",
        user.id
      )
    else
      # Regular agents (User) receive 'agent' or 'main_agent' payouts.
      # There is only one main agent, so no per-agent filtering is needed.
      CommissionPayout.where(payout_to: ['agent', 'main_agent'])
    end
  end

  def get_sub_agent_payouts_for_period(start_date, end_date)
    get_all_sub_agent_payouts.where(payout_date: start_date..end_date)
  end

  def format_payout_data(payout)
    begin
      policy = payout.policy
      customer = policy&.customer

      gross = payout.gross_commission_amount.to_f
      tds   = payout.tds_amount.to_f
      net   = payout.net_amount.to_f

      {
        id: payout.id,
        policy_number: payout.policy_number,
        policy_type: format_policy_type(payout.policy_type),
        customer_name: customer&.display_name || 'Unknown Customer',
        commission_amount: format_currency(gross),
        commission_amount_raw: gross.round(2).to_s,
        tds_percentage: payout.tds_percentage.to_f,
        tds_amount: format_currency(tds),
        tds_amount_raw: tds.round(2),
        net_amount: format_currency(net),
        net_amount_raw: net.round(2).to_s,
        commission_percentage: payout.payout_percentage || 0,
        status: payout.status&.titleize || 'Unknown',
        status_raw: payout.status,
        payout_date: payout.payout_date&.strftime("%d %b, %Y"),
        payout_date_raw: payout.payout_date&.iso8601,
        created_date: payout.created_at&.strftime("%d %b, %Y"),
        created_date_raw: payout.created_at&.iso8601,
        payment_mode: payout.payment_mode,
        transaction_id: payout.transaction_id,
        reference_number: payout.reference_number
      }
    rescue => e
      Rails.logger.error "Error formatting payout data for payout ID #{payout.id}: #{e.message}"
      {
        id: payout.id,
        policy_number: payout.policy_number || 'N/A',
        policy_type: format_policy_type(payout.policy_type),
        customer_name: 'Unknown Customer',
        commission_amount: format_currency(payout.payout_amount),
        commission_amount_raw: payout.payout_amount.to_f.round(2).to_s,
        tds_percentage: 0,
        tds_amount: format_currency(0),
        tds_amount_raw: 0,
        net_amount: format_currency(payout.payout_amount),
        net_amount_raw: payout.payout_amount.to_f.round(2).to_s,
        commission_percentage: 0,
        status: payout.status&.titleize || 'Unknown',
        status_raw: payout.status,
        payout_date: payout.payout_date&.strftime("%d %b, %Y"),
        payout_date_raw: payout.payout_date&.iso8601,
        created_date: payout.created_at&.strftime("%d %b, %Y"),
        created_date_raw: payout.created_at&.iso8601,
        payment_mode: nil,
        transaction_id: nil,
        reference_number: nil
      }
    end
  end

  def format_policy_type(policy_type)
    case policy_type.downcase
    when 'health'
      'Health Insurance'
    when 'life'
      'Life Insurance'
    when 'motor'
      'Motor Insurance'
    when 'other'
      'Other Insurance'
    else
      policy_type.titleize
    end
  end

  def format_currency(amount)
    return 'Rs. 0.00' if amount.nil? || amount.zero?
    amount = amount.to_f
    integer_part = amount.to_i.to_s
    decimal_part = sprintf("%.2f", amount).split('.').last
    reversed = integer_part.reverse
    result = []
    reversed.chars.each_with_index do |char, index|
      result << char
      if index == 2 && reversed.length > 3
        result << ','
      elsif index > 2 && (index - 2) % 2 == 0 && index < reversed.length - 1
        result << ','
      end
    end
    "Rs. #{result.reverse.join}.#{decimal_part}"
  end
end