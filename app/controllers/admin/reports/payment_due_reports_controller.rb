class Admin::Reports::PaymentDueReportsController < Admin::Reports::BaseController
  def index
    @payment_due_records = []

    # Get all unpaid policies
    @payment_due_records += get_health_payment_due
    @payment_due_records += get_motor_payment_due
    @payment_due_records += get_life_payment_due

    # Apply filters
    @payment_due_records = filter_payment_due(@payment_due_records)

    # Sort by due date
    @payment_due_records.sort_by! { |record| record[:payment_due_date] || Date.current + 1000.days }

    # Statistics
    @statistics = {
      total_due_amount: @payment_due_records.sum { |r| r[:outstanding_amount] },
      total_policies: @payment_due_records.count,
      by_type: @payment_due_records.group_by { |r| r[:insurance_type] }.transform_values(&:count),
      overdue_count: @payment_due_records.count { |r| r[:is_overdue] },
      due_ranges: {
        'Overdue' => @payment_due_records.count { |r| r[:is_overdue] },
        'Due in 7 days' => @payment_due_records.count { |r| r[:days_until_due] && r[:days_until_due] <= 7 && r[:days_until_due] >= 0 },
        'Due in 45 days' => @payment_due_records.count { |r| r[:days_until_due] && r[:days_until_due] <= 45 && r[:days_until_due] >= 0 },
        'Due later' => @payment_due_records.count { |r| r[:days_until_due] && r[:days_until_due] > 45 }
      }
    }

    # Paginate
    @payment_due_records = Kaminari.paginate_array(@payment_due_records).page(params[:page]).per(50)
  end

  def export
    redirect_to admin_reports_payment_due_reports_path(format: :csv)
  end

  private

  def get_health_payment_due
    HealthInsurance.includes(:customer, :sub_agent)
                  .map { |policy| format_payment_due_data(policy, 'Health') }
  end

  def get_motor_payment_due
    MotorInsurance.includes(:customer, :sub_agent)
                 .map { |policy| format_payment_due_data(policy, 'Motor') }
  end

  def get_life_payment_due
    LifeInsurance.includes(:customer, :sub_agent)
                .map { |policy| format_payment_due_data(policy, 'Life') }
  end

  def format_payment_due_data(policy, type)
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
      is_overdue: days_until_due ? days_until_due < 0 : false,
      payment_status: policy.try(:payment_status) || 'pending',
      affiliate: policy.sub_agent&.display_name || 'Self',
      policy_object: policy
    }
  end

  def filter_payment_due(records)
    # Filter by insurance type
    records = records.select { |r| r[:insurance_type] == params[:insurance_type] } if params[:insurance_type].present?

    # Filter by status
    case params[:status]
    when 'overdue'
      records = records.select { |r| r[:is_overdue] }
    when 'due_soon'
      records = records.select { |r| r[:days_until_due] && r[:days_until_due] <= 7 && r[:days_until_due] >= 0 }
    when 'due_later'
      records = records.select { |r| r[:days_until_due] && r[:days_until_due] > 7 }
    end

    # Search filter
    if params[:search].present?
      search_term = params[:search].downcase
      records = records.select do |r|
        r[:customer_name].downcase.include?(search_term) ||
        r[:policy_number].downcase.include?(search_term) ||
        r[:customer_email]&.downcase&.include?(search_term)
      end
    end

    records
  end
end