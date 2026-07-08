class Admin::Payout2Controller < Admin::ApplicationController
  def index
    @payouts = fetch_payouts_with_details
    @total_payouts = @payouts.count
    @total_amount = @payouts.sum { |p| p[:total_commission] }
    @paid_amount = @payouts.select { |p| p[:paid_count] == p[:total_count] }.sum { |p| p[:total_commission] }
    @pending_amount = @total_amount - @paid_amount
  end

  def mark_as_paid
    @payout = find_payout_by_type_and_id
    commission_payouts = CommissionPayout.where(
      policy_type: params[:policy_type],
      policy_id: params[:policy_id]
    )

    commission_payouts.update_all(
      status: 'paid',
      processed_at: Time.current,
      processed_by: current_user.email
    )

    redirect_to admin_payout2_index_path, notice: 'All commissions marked as paid successfully!'
  end

  def commission_breakdown
    begin
      @policy = find_payout_by_type_and_id
      @commission_payouts = CommissionPayout.where(
        policy_type: params[:policy_type],
        policy_id: params[:policy_id]
      )

      respond_to do |format|
        format.html
        format.json do
          render json: {
            policy: {
              number: @policy.try(:policy_number) || 'Unknown',
              type: params[:policy_type].capitalize,
              customer: @policy.try(:customer)&.display_name || 'Unknown',
              company: @policy.try(:insurance_company_name) || 'Unknown'
            },
            commissions: @commission_payouts.map do |cp|
              {
                type: cp.payout_to.humanize,
                amount: cp.payout_amount.to_f,
                status: cp.status,
                date: cp.payout_date,
                reference: cp.reference_number || 'No Reference'
              }
            end
          }
        end
      end
    rescue => e
      respond_to do |format|
        format.json do
          render json: {
            error: "Failed to load commission breakdown: #{e.message}",
            policy: {
              number: 'Error',
              type: params[:policy_type],
              customer: 'Error',
              company: 'Error'
            },
            commissions: []
          }, status: 500
        end
      end
    end
  end

  private

  def fetch_payouts_with_details
    # Get all commission payouts with their policy information in a single optimized query
    commission_data = CommissionPayout.joins(
      "LEFT JOIN life_insurances ON commission_payouts.policy_type = 'life' AND commission_payouts.policy_id = life_insurances.id " +
      "LEFT JOIN health_insurances ON commission_payouts.policy_type = 'health' AND commission_payouts.policy_id = health_insurances.id " +
      "LEFT JOIN motor_insurances ON commission_payouts.policy_type = 'motor' AND commission_payouts.policy_id = motor_insurances.id " +
      "LEFT JOIN other_insurances ON commission_payouts.policy_type = 'other' AND commission_payouts.policy_id = other_insurances.id " +
      "LEFT JOIN policies ON commission_payouts.policy_type = 'other' AND other_insurances.policy_id = policies.id " +
      "LEFT JOIN customers ON (life_insurances.customer_id = customers.id OR health_insurances.customer_id = customers.id OR motor_insurances.customer_id = customers.id OR policies.customer_id = customers.id)"
    ).select(
      "commission_payouts.policy_type, commission_payouts.policy_id, " +
      "commission_payouts.payout_to, commission_payouts.payout_amount, commission_payouts.status, " +
      "COALESCE(life_insurances.policy_number, health_insurances.policy_number, motor_insurances.policy_number, policies.policy_number) as policy_number, " +
      "COALESCE(life_insurances.insurance_company_name, health_insurances.insurance_company_name, motor_insurances.insurance_company_name, 'Other Insurance') as company_name, " +
      "COALESCE(life_insurances.total_premium, health_insurances.total_premium, motor_insurances.total_premium, policies.total_premium) as total_premium, " +
      "COALESCE(life_insurances.created_at, health_insurances.created_at, motor_insurances.created_at, other_insurances.created_at) as policy_created_at, " +
      "customers.first_name, customers.last_name, customers.company_name as customer_company_name, customers.customer_type, " +
      "COALESCE(life_insurances.sub_agent_commission_percentage, health_insurances.sub_agent_commission_percentage, 0) as sub_agent_percentage, " +
      "COALESCE(life_insurances.ambassador_commission_percentage, health_insurances.ambassador_commission_percentage, 0) as ambassador_percentage, " +
      "COALESCE(life_insurances.investor_commission_percentage, health_insurances.investor_commission_percentage, 0) as investor_percentage, " +
      "COALESCE(life_insurances.company_expenses_percentage, health_insurances.company_expenses_percentage, 0) as company_percentage"
    ).group_by { |cp| "#{cp.policy_type}_#{cp.policy_id}" }

    payouts = []

    commission_data.each do |policy_key, commissions|
      next if commissions.empty?

      first_commission = commissions.first

      # Calculate totals and breakdowns
      total_commission = commissions.sum(&:payout_amount)
      paid_count = commissions.count { |cp| cp.status == 'paid' }
      total_count = commissions.count

      # Group by payout type for breakdown
      breakdown = commissions.group_by(&:payout_to).transform_values { |cps| cps.sum(&:payout_amount) }

      # Get customer name
      customer_name = if first_commission.customer_type == 'individual'
                        "#{first_commission.first_name} #{first_commission.last_name}".strip
                      else
                        first_commission.customer_company_name
                      end

      payouts << {
        policy_id: first_commission.policy_id,
        policy_type: first_commission.policy_type,
        policy_number: first_commission.policy_number || 'Unknown',
        customer_name: customer_name.presence || 'Unknown',
        company_name: first_commission.company_name || 'Unknown',
        premium_amount: first_commission.total_premium || 0,
        total_commission: total_commission,
        main_agent_commission: breakdown['main_agent'] || 0,
        main_agent_percentage: calculate_percentage_from_premium(breakdown['main_agent'], first_commission.total_premium),
        paid_count: paid_count,
        total_count: total_count,
        transfer_status: paid_count == total_count ? 'Completed' : "#{paid_count}/#{total_count}",
        breakdown: {
          affiliate: {
            amount: breakdown['affiliate'] || 0,
            percentage: first_commission.sub_agent_percentage || 0
          },
          ambassador: {
            amount: breakdown['ambassador'] || 0,
            percentage: first_commission.ambassador_percentage || 0
          },
          investor: {
            amount: breakdown['investor'] || 0,
            percentage: first_commission.investor_percentage || 0
          },
          company: {
            amount: breakdown['company_expense'] || 0,
            percentage: first_commission.company_percentage || 0
          }
        },
        created_at: first_commission.policy_created_at || Time.current
      }
    end

    payouts.sort_by { |p| p[:created_at] }.reverse
  end

  def get_model_class(policy_type)
    case policy_type
    when 'life'
      LifeInsurance
    when 'health'
      HealthInsurance
    when 'motor'
      MotorInsurance
    when 'other'
      OtherInsurance
    else
      nil
    end
  end

  def find_payout_by_type_and_id
    model_class = get_model_class(params[:policy_type])
    model_class&.find(params[:policy_id])
  end

  def calculate_percentage(amount, policy)
    return 0 if !amount || amount == 0 || !policy.respond_to?(:total_premium) || policy.total_premium == 0
    ((amount / policy.total_premium) * 100).round(2)
  end

  def calculate_percentage_from_premium(amount, premium)
    return 0 if !amount || amount == 0 || !premium || premium == 0
    ((amount / premium) * 100).round(2)
  end

  def calculate_commission_percentage(policy, field)
    return 0 unless policy.respond_to?(field)
    policy.try(field) || 0
  end
end