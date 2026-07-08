class Admin::Reports::UpcomingPaymentReportsController < Admin::Reports::BaseController
  def index
    @upcoming_payments = []

    # Get payments due in next 60 days
    end_date = Date.current + 60.days

    @upcoming_payments += get_upcoming_health_payments(end_date)
    @upcoming_payments += get_upcoming_motor_payments(end_date)
    @upcoming_payments += get_upcoming_life_payments(end_date)

    # Apply filters
    @upcoming_payments = filter_upcoming_payments(@upcoming_payments)

    # Sort by payment due date
    @upcoming_payments.sort_by! { |p| p[:payment_due_date] || Date.current + 1000.days }

    # Statistics
    @statistics = {
      total_upcoming_amount: @upcoming_payments.sum { |p| p[:outstanding_amount] },
      total_payments: @upcoming_payments.count,
      by_type: @upcoming_payments.group_by { |p| p[:insurance_type] }.transform_values(&:count),
      by_timeframe: {
        'Due today' => @upcoming_payments.count { |p| p[:payment_due_date] == Date.current },
        'Due this week' => @upcoming_payments.count { |p| p[:days_until_due] && p[:days_until_due] <= 7 && p[:days_until_due] >= 0 },
        'Due in 15 days' => @upcoming_payments.count { |p| p[:days_until_due] && p[:days_until_due] <= 15 && p[:days_until_due] >= 0 },
        'Due in 45 days' => @upcoming_payments.count { |p| p[:days_until_due] && p[:days_until_due] <= 45 && p[:days_until_due] >= 0 },
        'Due in 60 days' => @upcoming_payments.count { |p| p[:days_until_due] && p[:days_until_due] <= 60 && p[:days_until_due] >= 0 }
      }
    }

    # Paginate
    @upcoming_payments = Kaminari.paginate_array(@upcoming_payments).page(params[:page]).per(50)
  end

  def export
    redirect_to admin_reports_upcoming_payment_reports_path(format: :csv)
  end

  private

  def get_upcoming_health_payments(end_date)
    HealthInsurance.includes(:customer, :sub_agent)
                  .where('policy_start_date BETWEEN ? AND ?', Date.current, end_date)
                  .map { |policy| format_upcoming_payment_data(policy, 'Health') }
  end

  def get_upcoming_motor_payments(end_date)
    MotorInsurance.includes(:customer, :sub_agent)
                 .where('policy_start_date BETWEEN ? AND ?', Date.current, end_date)
                 .map { |policy| format_upcoming_payment_data(policy, 'Motor') }
  end

  def get_upcoming_life_payments(end_date)
    LifeInsurance.includes(:customer, :sub_agent)
                .where('policy_start_date BETWEEN ? AND ?', Date.current, end_date)
                .map { |policy| format_upcoming_payment_data(policy, 'Life') }
  end

  def format_upcoming_payment_data(policy, type)
    payment_due_date = policy.try(:payment_due_date) || policy.policy_start_date
    days_until_due = payment_due_date ? (payment_due_date - Date.current).to_i : nil

    {
      id: policy.id,
      insurance_type: type,
      policy_number: policy.policy_number,
      customer_name: policy.customer&.display_name || 'Unknown',
      customer_email: policy.customer&.email,
      customer_mobile: policy.customer&.mobile,
      total_premium: policy.total_premium || 0,
      paid_amount: policy.try(:paid_amount) || 0,
      outstanding_amount: (policy.total_premium || 0) - (policy.try(:paid_amount) || 0),
      payment_due_date: payment_due_date,
      days_until_due: days_until_due,
      payment_method: policy.try(:payment_mode) || 'Unknown',
      affiliate: policy.sub_agent&.display_name || 'Self',
      urgency: get_payment_urgency(days_until_due),
      policy_object: policy
    }
  end

  def get_payment_urgency(days)
    return 'overdue' if days && days < 0

    case days
    when 0
      'due_today'
    when 1..3
      'due_soon'
    when 4..7
      'due_this_week'
    when 8..15
      'due_in_15_days'
    when 16..30
      'due_in_month'
    else
      'due_later'
    end
  end

  def filter_upcoming_payments(payments)
    # Filter by insurance type
    payments = payments.select { |p| p[:insurance_type] == params[:insurance_type] } if params[:insurance_type].present?

    # Filter by urgency
    payments = payments.select { |p| p[:urgency] == params[:urgency] } if params[:urgency].present?

    # Filter by timeframe
    if params[:timeframe].present?
      case params[:timeframe]
      when 'due_today'
        payments = payments.select { |p| p[:days_until_due] == 0 }
      when 'due_this_week'
        payments = payments.select { |p| p[:days_until_due] && p[:days_until_due] <= 7 && p[:days_until_due] >= 0 }
      when 'due_in_15_days'
        payments = payments.select { |p| p[:days_until_due] && p[:days_until_due] <= 15 && p[:days_until_due] >= 0 }
      when 'due_in_month'
        payments = payments.select { |p| p[:days_until_due] && p[:days_until_due] <= 45 && p[:days_until_due] >= 0 }
      end
    end

    # Search filter
    if params[:search].present?
      search_term = params[:search].downcase
      payments = payments.select do |p|
        p[:customer_name].downcase.include?(search_term) ||
        p[:policy_number].downcase.include?(search_term) ||
        p[:customer_email]&.downcase&.include?(search_term)
      end
    end

    payments
  end
end