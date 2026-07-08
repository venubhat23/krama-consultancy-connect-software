class Admin::Reports::AllPolicyReportsController < Admin::Reports::BaseController
  include ActionView::Helpers::NumberHelper
  before_action :authenticate_user!
  before_action :ensure_admin_or_authorized_user
  before_action :set_filter_params

  def index
    # Fetch once unpaginated, compute all aggregates, then paginate the array
    all_policies = fetch_policy_data(paginated: false)
    @total_policies   = all_policies.size
    @total_premium    = all_policies.sum { |p| p[:premium_amount] || 0 }
    @total_sum_insured = all_policies.sum { |p| p[:sum_insured] || 0 }

    @policy_data  = Kaminari.paginate_array(all_policies).page(params[:page]).per(50)
    @policy_count = @policy_data.total_count

    # Filter options for dropdowns
    @insurance_companies = get_insurance_companies
    @policy_types = ['all', 'health', 'life', 'motor', 'other']
    @status_options = ['all', 'active', 'expired', 'expiring_soon']

    respond_to do |format|
      format.html
      format.json { render json: policy_data_json }
    end
  end

  def export_pdf
    @policy_data = fetch_policy_data(paginated: false)
    @selected_columns = params[:columns] || default_columns

    respond_to do |format|
      format.pdf do
        render template: 'admin/reports/all_policy_reports/export_pdf',
               layout: 'pdf',
               content_type: 'text/html'
      end
    end
  end

  private

  def fetch_policy_data(paginated: true)
    # Combine all policy types into a unified query result
    policies = []

    if @policy_type == 'all' || @policy_type == 'health'
      health_policies = HealthInsurance.includes(:customer, :sub_agent)
                                      .where(created_at: @start_date.beginning_of_day..@end_date.end_of_day)
      health_policies = apply_health_filters(health_policies) if @insurance_company.present? || @status.present?
      policies += health_policies.map { |p| transform_health_policy(p) }
    end

    if @policy_type == 'all' || @policy_type == 'motor'
      motor_policies = MotorInsurance.includes(:customer, :sub_agent)
                                    .where(created_at: @start_date.beginning_of_day..@end_date.end_of_day)
      motor_policies = apply_motor_filters(motor_policies) if @insurance_company.present? || @status.present?
      policies += motor_policies.map { |p| transform_motor_policy(p) }
    end

    if @policy_type == 'all' || @policy_type == 'life'
      if defined?(LifeInsurance)
        life_policies = LifeInsurance.includes(:customer, :sub_agent)
                                    .where(created_at: @start_date.beginning_of_day..@end_date.end_of_day)
        life_policies = apply_life_filters(life_policies) if @insurance_company.present? || @status.present?
        policies += life_policies.map { |p| transform_life_policy(p) }
      end
    end

    if @policy_type == 'all' || @policy_type == 'other'
      if defined?(OtherInsurance)
        other_policies = OtherInsurance.includes(:customer, :sub_agent)
                                      .where(created_at: @start_date.beginning_of_day..@end_date.end_of_day)
        other_policies = apply_other_filters(other_policies) if @insurance_company.present? || @status.present?
        policies += other_policies.map { |p| transform_other_policy(p) }
      end
    end

    # Apply status filter
    if @status.present? && @status != 'all'
      policies = policies.select { |policy| policy[:status].downcase == @status }
    end

    # Sort by latest first and apply pagination
    policies = policies.sort_by { |p| p[:created_at] }.reverse

    if paginated
      Kaminari.paginate_array(policies)
    else
      policies.first(10000) # Limit for exports
    end
  end

  def calculate_total_policies
    fetch_policy_data(paginated: false).size
  end

  def calculate_total_premium
    fetch_policy_data(paginated: false).sum { |p| p[:premium_amount] || 0 }
  end

  def calculate_total_sum_insured
    fetch_policy_data(paginated: false).sum { |p| p[:sum_insured] || 0 }
  end

  def apply_health_filters(query)
    query = query.where('insurance_company_name ILIKE ?', "%#{@insurance_company}%") if @insurance_company.present?
    query
  end

  def apply_motor_filters(query)
    query = query.where('insurance_company_name ILIKE ?', "%#{@insurance_company}%") if @insurance_company.present?
    query
  end

  def apply_life_filters(query)
    query = query.where('insurance_company_name ILIKE ?', "%#{@insurance_company}%") if @insurance_company.present?
    query
  end

  def apply_other_filters(query)
    query = query.where('insurance_company_name ILIKE ?', "%#{@insurance_company}%") if @insurance_company.present?
    query
  end

  def transform_health_policy(policy)
    {
      id: policy.id,
      policy_number: policy.policy_number || 'N/A',
      policy_type: 'Health',
      customer_name: policy.customer&.display_name || 'Unknown',
      insurance_company: policy.insurance_company_name || 'N/A',
      policy_holder: policy.policy_holder || 'N/A',
      start_date: policy.policy_start_date,
      end_date: policy.policy_end_date,
      premium_amount: policy.total_premium || 0,
      sum_insured: policy.sum_insured || 0,
      payment_mode: policy.payment_mode || 'N/A',
      status: calculate_status(policy.policy_end_date),
      sub_agent_name: policy.sub_agent&.full_name || 'N/A',
      created_at: policy.created_at,
      lead_id: policy.lead_id
    }
  end

  def transform_motor_policy(policy)
    {
      id: policy.id,
      policy_number: policy.policy_number || 'N/A',
      policy_type: 'Motor',
      customer_name: policy.customer&.display_name || 'Unknown',
      insurance_company: policy.insurance_company_name || 'N/A',
      policy_holder: policy.policy_holder || 'N/A',
      start_date: policy.policy_start_date,
      end_date: policy.policy_end_date,
      premium_amount: policy.total_premium || 0,
      sum_insured: policy.total_idv || policy.sum_insured || 0,
      payment_mode: policy.payment_mode || 'N/A',
      status: calculate_status(policy.policy_end_date),
      sub_agent_name: policy.sub_agent&.full_name || 'N/A',
      created_at: policy.created_at,
      lead_id: policy.lead_id
    }
  end

  def transform_life_policy(policy)
    {
      id: policy.id,
      policy_number: policy.policy_number || 'N/A',
      policy_type: 'Life',
      customer_name: policy.customer&.display_name || 'Unknown',
      insurance_company: policy.insurance_company_name || 'N/A',
      policy_holder: policy.policy_holder || 'N/A',
      start_date: policy.policy_start_date,
      end_date: policy.policy_end_date,
      premium_amount: policy.total_premium || 0,
      sum_insured: policy.sum_insured || 0,
      payment_mode: policy.payment_mode || 'N/A',
      status: calculate_status(policy.policy_end_date),
      sub_agent_name: policy.sub_agent&.full_name || 'N/A',
      created_at: policy.created_at,
      lead_id: policy.lead_id
    }
  end

  def transform_other_policy(policy)
    {
      id: policy.id,
      policy_number: policy.policy_number || 'N/A',
      policy_type: 'Other',
      customer_name: policy.customer&.display_name || 'Unknown',
      insurance_company: policy.insurance_company_name || 'N/A',
      policy_holder: policy.policy_holder || 'N/A',
      start_date: policy.policy_start_date,
      end_date: policy.policy_end_date,
      premium_amount: policy.total_premium || 0,
      sum_insured: policy.sum_insured || 0,
      payment_mode: policy.payment_mode || 'N/A',
      status: calculate_status(policy.policy_end_date),
      sub_agent_name: policy.sub_agent&.full_name || 'N/A',
      created_at: policy.created_at,
      lead_id: policy.lead_id
    }
  end

  def calculate_status(end_date)
    return 'Active' unless end_date.present?

    if end_date < Date.current
      'Expired'
    elsif end_date <= 30.days.from_now
      'Expiring Soon'
    else
      'Active'
    end
  end

  def get_insurance_companies
    companies = []
    ['HealthInsurance', 'LifeInsurance', 'MotorInsurance', 'OtherInsurance'].each do |model_name|
      next unless defined?(model_name.constantize)
      companies += model_name.constantize.distinct.pluck(:insurance_company_name).compact
    end
    companies.uniq.sort
  end

  def policy_data_json
    {
      data: @policy_data.map do |policy|
        {
          id: policy[:id],
          policy_number: policy[:policy_number],
          policy_type: policy[:policy_type],
          customer_name: policy[:customer_name],
          insurance_company: policy[:insurance_company],
          policy_holder: policy[:policy_holder],
          start_date: policy[:start_date]&.strftime('%d/%m/%Y'),
          end_date: policy[:end_date]&.strftime('%d/%m/%Y'),
          premium_amount: policy[:premium_amount],
          sum_insured: policy[:sum_insured],
          payment_mode: policy[:payment_mode],
          status: policy[:status],
          sub_agent_name: policy[:sub_agent_name],
          created_at: policy[:created_at]&.strftime('%d/%m/%Y'),
          lead_id: policy[:lead_id]
        }
      end,
      pagination: {
        current_page: @policy_data.current_page,
        total_pages: @policy_data.total_pages,
        total_count: @policy_data.total_count
      },
      summary: {
        total_policies: @total_policies,
        total_premium: @total_premium,
        total_sum_insured: @total_sum_insured
      }
    }
  end

  def default_columns
    %w[policy_number policy_type customer_name insurance_company policy_holder start_date end_date premium_amount sum_insured payment_mode status sub_agent_name created_at]
  end

  def set_filter_params
    @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : 30.days.ago.to_date
    @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current
    @policy_type = params[:policy_type] || 'all'
    @insurance_company = params[:insurance_company]
    @status = params[:status] || 'all'
  end

  def ensure_admin_or_authorized_user
    redirect_to root_path unless current_user.admin? || current_user.can_view_reports?
  end
end