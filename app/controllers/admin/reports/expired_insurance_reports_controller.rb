class Admin::Reports::ExpiredInsuranceReportsController < Admin::Reports::BaseController
  include ActionView::Helpers::NumberHelper
  before_action :authenticate_user!
  before_action :ensure_admin_or_authorized_user
  before_action :set_filter_params

  def index
    # Get expired policy data with latest records on top
    @expired_data = fetch_expired_data

    # Summary calculations (before pagination)
    @total_expired = calculate_total_expired
    @total_premium_lost = calculate_total_premium_lost
    @total_sum_insured_lost = calculate_total_sum_insured_lost

    # Pagination
    @expired_data = @expired_data.page(params[:page]).per(50)

    # Set counts for display
    @expired_count = @total_expired
    @policy_count = @total_expired  # For consistency with view

    # Variables for saved reports section (if applicable)
    @saved_reports = []
    @total_reports = 0
    @this_month_reports = 0
    @last_generated = nil

    # Filter options for dropdowns
    @insurance_companies = get_insurance_companies
    @policy_types = ['all', 'health', 'life', 'motor', 'other']

    respond_to do |format|
      format.html
      format.json { render json: expired_data_json }
    end
  end

  def preview
    @expired_data = fetch_expired_data
    @selected_columns = params[:columns] || default_columns

    respond_to do |format|
      format.html { render 'preview' }
      format.json { render json: expired_data_json }
    end
  end

  def create_report
    @expired_data = fetch_expired_data(paginated: false)
    @selected_columns = params[:columns] || default_columns

    respond_to do |format|
      format.html { redirect_to admin_reports_expired_insurance_reports_path, notice: 'Report generated successfully!' }
      format.json { render json: { message: 'Report generated successfully!', data: expired_data_json } }
    end
  end

  def export_pdf
    @expired_data = fetch_expired_data(paginated: false)
    @selected_columns = params[:columns] || default_columns

    respond_to do |format|
      format.pdf do
        render template: 'admin/reports/expired_insurance_reports/export_pdf',
               layout: 'pdf',
               content_type: 'text/html'
      end
    end
  end

  def export_csv
    @expired_data = fetch_expired_data(paginated: false)
    @selected_columns = params[:columns] || default_columns

    respond_to do |format|
      format.html do
        # Handle HTML requests by generating CSV and sending as download
        csv_data = generate_csv_data
        send_data csv_data,
                  filename: "expired_insurance_report_#{Date.current.strftime('%Y%m%d')}.csv",
                  type: 'text/csv',
                  disposition: 'attachment'
      end
      format.csv do
        csv_data = generate_csv_data
        send_data csv_data,
                  filename: "expired_insurance_report_#{Date.current.strftime('%Y%m%d')}.csv",
                  type: 'text/csv'
      end
    end
  end

  private

  def fetch_expired_data(paginated: true)
    # Find all expired policies across different types
    expired_policies = []

    if @policy_type == 'all' || @policy_type == 'health'
      health_expired = HealthInsurance.includes(:customer, :sub_agent)
                                     .where('policy_end_date < ?', Date.current)
                                     .where(created_at: @start_date.beginning_of_day..@end_date.end_of_day)
      health_expired = apply_health_filters(health_expired) if @insurance_company.present?
      expired_policies += health_expired.map { |p| transform_health_policy(p) }
    end

    if @policy_type == 'all' || @policy_type == 'motor'
      motor_expired = MotorInsurance.includes(:customer, :sub_agent)
                                   .where('policy_end_date < ?', Date.current)
                                   .where(created_at: @start_date.beginning_of_day..@end_date.end_of_day)
      motor_expired = apply_motor_filters(motor_expired) if @insurance_company.present?
      expired_policies += motor_expired.map { |p| transform_motor_policy(p) }
    end

    if @policy_type == 'all' || @policy_type == 'life'
      if defined?(LifeInsurance)
        life_expired = LifeInsurance.includes(:customer, :sub_agent)
                                   .where('policy_end_date < ?', Date.current)
                                   .where(created_at: @start_date.beginning_of_day..@end_date.end_of_day)
        life_expired = apply_life_filters(life_expired) if @insurance_company.present?
        expired_policies += life_expired.map { |p| transform_life_policy(p) }
      end
    end

    if @policy_type == 'all' || @policy_type == 'other'
      if defined?(OtherInsurance)
        other_expired = OtherInsurance.includes(:customer, :sub_agent)
                                     .where('policy_end_date < ?', Date.current)
                                     .where(created_at: @start_date.beginning_of_day..@end_date.end_of_day)
        other_expired = apply_other_filters(other_expired) if @insurance_company.present?
        expired_policies += other_expired.map { |p| transform_other_policy(p) }
      end
    end

    # Sort by expiry date (most recently expired first)
    expired_policies = expired_policies.sort_by { |p| p[:end_date] }.reverse

    if paginated
      Kaminari.paginate_array(expired_policies)
    else
      expired_policies.first(10000) # Limit for exports
    end
  end

  def calculate_total_expired
    fetch_expired_data(paginated: false).size
  end

  def calculate_total_premium_lost
    fetch_expired_data(paginated: false).sum { |p| p[:premium_amount] || 0 }
  end

  def calculate_total_sum_insured_lost
    fetch_expired_data(paginated: false).sum { |p| p[:sum_insured] || 0 }
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
      sub_agent_name: policy.sub_agent&.full_name || 'N/A',
      days_expired: calculate_days_expired(policy.policy_end_date),
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
      sub_agent_name: policy.sub_agent&.full_name || 'N/A',
      days_expired: calculate_days_expired(policy.policy_end_date),
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
      sub_agent_name: policy.sub_agent&.full_name || 'N/A',
      days_expired: calculate_days_expired(policy.policy_end_date),
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
      sub_agent_name: policy.sub_agent&.full_name || 'N/A',
      days_expired: calculate_days_expired(policy.policy_end_date),
      created_at: policy.created_at,
      lead_id: policy.lead_id
    }
  end

  def calculate_days_expired(end_date)
    return 0 unless end_date.present?
    (Date.current - end_date).to_i
  end

  def get_insurance_companies
    companies = []
    ['HealthInsurance', 'LifeInsurance', 'MotorInsurance', 'OtherInsurance'].each do |model_name|
      next unless defined?(model_name.constantize)
      companies += model_name.constantize.distinct.pluck(:insurance_company_name).compact
    end
    companies.uniq.sort
  end

  def expired_data_json
    {
      data: @expired_data.map do |policy|
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
          sub_agent_name: policy[:sub_agent_name],
          days_expired: policy[:days_expired],
          created_at: policy[:created_at]&.strftime('%d/%m/%Y'),
          lead_id: policy[:lead_id]
        }
      end,
      pagination: {
        current_page: @expired_data.current_page,
        total_pages: @expired_data.total_pages,
        total_count: @expired_data.total_count
      },
      summary: {
        total_expired: @total_expired,
        total_premium_lost: @total_premium_lost,
        total_sum_insured_lost: @total_sum_insured_lost
      }
    }
  end

  def generate_csv_data
    require 'csv'

    CSV.generate(headers: true) do |csv|
      # CSV headers based on selected columns
      headers = []
      headers << 'Policy Number' if @selected_columns.include?('policy_number')
      headers << 'Policy Type' if @selected_columns.include?('policy_type')
      headers << 'Customer Name' if @selected_columns.include?('customer_name')
      headers << 'Insurance Company' if @selected_columns.include?('insurance_company')
      headers << 'Policy Holder' if @selected_columns.include?('policy_holder')
      headers << 'Start Date' if @selected_columns.include?('start_date')
      headers << 'End Date' if @selected_columns.include?('end_date')
      headers << 'Premium Amount' if @selected_columns.include?('premium_amount')
      headers << 'Sum Insured' if @selected_columns.include?('sum_insured')
      headers << 'Payment Mode' if @selected_columns.include?('payment_mode')
      headers << 'Days Expired' if @selected_columns.include?('days_expired')
      headers << 'Sub Agent' if @selected_columns.include?('sub_agent_name')
      headers << 'Created Date' if @selected_columns.include?('created_at')
      headers << 'Lead ID' if @selected_columns.include?('lead_id')

      csv << headers

      # CSV data rows
      @expired_data.each do |policy|
        row = []
        row << policy[:policy_number] if @selected_columns.include?('policy_number')
        row << policy[:policy_type] if @selected_columns.include?('policy_type')
        row << policy[:customer_name] if @selected_columns.include?('customer_name')
        row << policy[:insurance_company] if @selected_columns.include?('insurance_company')
        row << policy[:policy_holder] if @selected_columns.include?('policy_holder')
        row << policy[:start_date]&.strftime('%d/%m/%Y') if @selected_columns.include?('start_date')
        row << policy[:end_date]&.strftime('%d/%m/%Y') if @selected_columns.include?('end_date')
        row << format_indian_currency_csv(policy[:premium_amount]) if @selected_columns.include?('premium_amount')
        row << format_indian_currency_csv(policy[:sum_insured]) if @selected_columns.include?('sum_insured')
        row << policy[:payment_mode] if @selected_columns.include?('payment_mode')
        row << "#{policy[:days_expired]} days" if @selected_columns.include?('days_expired')
        row << policy[:sub_agent_name] if @selected_columns.include?('sub_agent_name')
        row << policy[:created_at]&.strftime('%d/%m/%Y') if @selected_columns.include?('created_at')
        row << policy[:lead_id] if @selected_columns.include?('lead_id')

        csv << row
      end
    end
  end

  def default_columns
    %w[policy_number policy_type customer_name insurance_company end_date premium_amount sum_insured days_expired sub_agent_name]
  end

  def set_filter_params
    @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : 1.year.ago.to_date
    @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current
    @policy_type = params[:policy_type] || 'all'
    @insurance_company = params[:insurance_company]

    # Set @policy_count for consistency with view
    @policy_count = @expired_count if defined?(@expired_count)
  end

  def ensure_admin_or_authorized_user
    redirect_to root_path unless current_user.admin? || current_user.can_view_reports?
  end
end