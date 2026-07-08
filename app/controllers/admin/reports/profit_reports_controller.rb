class Admin::Reports::ProfitReportsController < Admin::Reports::BaseController
  include ActionView::Helpers::NumberHelper
  before_action :authenticate_user!
  before_action :ensure_admin_or_authorized_user
  before_action :set_filter_params

  def index
    # Get policy data with profit information
    @policy_data = fetch_policies_with_profit

    # Pagination
    @policy_data = @policy_data.page(params[:page]).per(50)

    # Summary calculations
    @total_policies = calculate_total_policies
    @total_profit_amount = calculate_total_profit_amount
    @total_premium = calculate_total_premium
    @average_profit_percentage = calculate_average_profit_percentage
    @policy_count = @policy_data.total_count

    # Filter options for dropdowns
    @insurance_companies = get_insurance_companies
    @policy_types = ['all', 'health', 'life', 'motor', 'other']

    respond_to do |format|
      format.html
      format.json { render json: policy_data_json }
    end
  end

  def export_pdf
    @policy_data = fetch_policies_with_profit(paginated: false)
    @selected_columns = params[:columns] || default_columns

    respond_to do |format|
      format.pdf do
        render template: 'admin/reports/profit_reports/export_pdf',
               layout: 'pdf',
               content_type: 'text/html'
      end
    end
  end

  def export_csv
    @policy_data = fetch_policies_with_profit(paginated: false)
    @selected_columns = params[:columns] || default_columns

    respond_to do |format|
      format.html do
        # Handle HTML requests by generating CSV and sending as download
        csv_data = generate_csv_data
        send_data csv_data,
                  filename: "profit_report_#{Date.current.strftime('%Y%m%d')}.csv",
                  type: 'text/csv',
                  disposition: 'attachment'
      end
      format.csv do
        csv_data = generate_csv_data
        send_data csv_data,
                  filename: "profit_report_#{Date.current.strftime('%Y%m%d')}.csv",
                  type: 'text/csv'
      end
    end
  end

  private

  def fetch_policies_with_profit(paginated: true)
    # Combine all policy types into a unified query result
    policies = []

    if @policy_type == 'all' || @policy_type == 'health'
      health_policies = HealthInsurance.includes(:customer, :sub_agent)
                                      .where(policy_start_date: @start_date..@end_date)
      health_policies = apply_health_filters(health_policies) if @insurance_company.present?
      policies += health_policies.map { |p| transform_health_policy_profit(p) }
    end

    if @policy_type == 'all' || @policy_type == 'motor'
      motor_policies = MotorInsurance.includes(:customer, :sub_agent)
                                    .where(policy_start_date: @start_date..@end_date)
      motor_policies = apply_motor_filters(motor_policies) if @insurance_company.present?
      policies += motor_policies.map { |p| transform_motor_policy_profit(p) }
    end

    if @policy_type == 'all' || @policy_type == 'life'
      if defined?(LifeInsurance)
        life_policies = LifeInsurance.includes(:customer, :sub_agent)
                                    .where(policy_start_date: @start_date..@end_date)
        life_policies = apply_life_filters(life_policies) if @insurance_company.present?
        policies += life_policies.map { |p| transform_life_policy_profit(p) }
      end
    end

    if @policy_type == 'all' || @policy_type == 'other'
      if defined?(OtherInsurance)
        other_policies = OtherInsurance.includes(:customer, :sub_agent)
                                      .where(policy_start_date: @start_date..@end_date)
        other_policies = apply_other_filters(other_policies) if @insurance_company.present?
        policies += other_policies.map { |p| transform_other_policy_profit(p) }
      end
    end

    # Sort by profit amount (highest first)
    policies = policies.sort_by { |p| -(p[:profit_amount] || 0) }

    if paginated
      Kaminari.paginate_array(policies)
    else
      policies.first(10000) # Limit for exports
    end
  end

  def calculate_total_policies
    fetch_policies_with_profit(paginated: false).size
  end

  def calculate_total_profit_amount
    fetch_policies_with_profit(paginated: false).sum { |p| p[:profit_amount] || 0 }
  end

  def calculate_total_premium
    fetch_policies_with_profit(paginated: false).sum { |p| p[:premium_amount] || 0 }
  end

  def calculate_average_profit_percentage
    policies = fetch_policies_with_profit(paginated: false)
    return 0 if policies.empty?

    total_profit_percentage = policies.sum { |p| p[:profit_percentage] || 0 }
    (total_profit_percentage / policies.size).round(2)
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

  def transform_health_policy_profit(policy)
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
      net_premium: policy.net_premium || 0,
      profit_amount: policy.profit_amount || 0,
      profit_percentage: policy.profit_percentage || 0,
      company_expenses: policy.respond_to?(:company_expenses_amount) ? (policy.company_expenses_amount || 0) : 0,
      sub_agent_name: policy.sub_agent&.full_name || 'Direct',
      created_at: policy.created_at,
      lead_id: policy.lead_id
    }
  end

  def transform_motor_policy_profit(policy)
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
      net_premium: policy.net_premium || 0,
      profit_amount: policy.profit_amount || 0,
      profit_percentage: policy.profit_percentage || 0,
      company_expenses: policy.respond_to?(:company_expenses_amount) ? (policy.company_expenses_amount || 0) : 0,
      sub_agent_name: policy.sub_agent&.full_name || 'Direct',
      created_at: policy.created_at,
      lead_id: policy.lead_id
    }
  end

  def transform_life_policy_profit(policy)
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
      net_premium: policy.net_premium || 0,
      profit_amount: policy.profit_amount || 0,
      profit_percentage: policy.profit_percentage || 0,
      company_expenses: policy.respond_to?(:company_expenses_amount) ? (policy.company_expenses_amount || 0) : 0,
      sub_agent_name: policy.sub_agent&.full_name || 'Direct',
      created_at: policy.created_at,
      lead_id: policy.lead_id
    }
  end

  def transform_other_policy_profit(policy)
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
      net_premium: policy.net_premium || 0,
      profit_amount: policy.profit_amount || 0,
      profit_percentage: policy.profit_percentage || 0,
      company_expenses: policy.respond_to?(:company_expenses_amount) ? (policy.company_expenses_amount || 0) : 0,
      sub_agent_name: policy.sub_agent&.full_name || 'Direct',
      created_at: policy.created_at,
      lead_id: policy.lead_id
    }
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
          net_premium: policy[:net_premium],
          profit_amount: policy[:profit_amount],
          profit_percentage: policy[:profit_percentage],
          company_expenses: policy[:company_expenses],
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
        total_profit_amount: @total_profit_amount,
        total_premium: @total_premium,
        average_profit_percentage: @average_profit_percentage
      }
    }
  end

  def generate_csv_data
    require 'csv'

    # Define column mappings
    column_headers = {
      'policy_number' => 'Policy Number',
      'policy_type' => 'Policy Type',
      'customer_name' => 'Customer Name',
      'insurance_company' => 'Insurance Company',
      'policy_holder' => 'Policy Holder',
      'start_date' => 'Start Date',
      'end_date' => 'End Date',
      'premium_amount' => 'Premium Amount',
      'net_premium' => 'Net Premium',
      'profit_amount' => 'Profit Amount',
      'profit_percentage' => 'Profit Percentage',
      'company_expenses' => 'Company Expenses',
      'sub_agent_name' => 'Sub Agent',
      'created_at' => 'Created Date'
    }

    CSV.generate(headers: true) do |csv|
      # Generate headers based on selected columns
      headers = @selected_columns.map { |col| column_headers[col] || col.humanize }
      csv << headers

      # Generate data rows based on selected columns
      @policy_data.each do |policy|
        row = @selected_columns.map do |col|
          case col
          when 'policy_number'
            policy[:policy_number]
          when 'policy_type'
            policy[:policy_type]
          when 'customer_name'
            policy[:customer_name]
          when 'insurance_company'
            policy[:insurance_company]
          when 'policy_holder'
            policy[:policy_holder]
          when 'start_date'
            policy[:start_date]&.strftime('%d/%m/%Y')
          when 'end_date'
            policy[:end_date]&.strftime('%d/%m/%Y')
          when 'premium_amount'
            "Rs. #{number_with_delimiter(policy[:premium_amount])}"
          when 'net_premium'
            "Rs. #{number_with_delimiter(policy[:net_premium])}"
          when 'profit_amount'
            "Rs. #{number_with_delimiter(policy[:profit_amount])}"
          when 'profit_percentage'
            "#{policy[:profit_percentage]}%"
          when 'company_expenses'
            "Rs. #{number_with_delimiter(policy[:company_expenses])}"
          when 'sub_agent_name'
            policy[:sub_agent_name]
          when 'created_at'
            policy[:created_at]&.strftime('%d/%m/%Y')
          else
            policy[col.to_sym] || ''
          end
        end
        csv << row
      end
    end
  end

  def default_columns
    %w[policy_number policy_type customer_name insurance_company policy_holder start_date end_date premium_amount net_premium profit_amount profit_percentage company_expenses sub_agent_name created_at]
  end

  def set_filter_params
    @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current.beginning_of_year
    @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current.end_of_year
    @policy_type = params[:policy_type] || 'all'
    @insurance_company = params[:insurance_company]
  end

  def ensure_admin_or_authorized_user
    redirect_to root_path unless current_user.admin? || current_user.can_view_reports?
  end
end