class Admin::Reports::CommissionReportsAdvancedController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin_or_authorized_user
  before_action :set_filter_params
  layout 'application'

  def index
    # Get commission data with latest records on top
    @commission_data = fetch_commission_data

    # Pagination
    @commission_data = @commission_data.page(params[:page]).per(50)

    # Summary calculations
    @total_commission = calculate_total_commission
    @total_tds = calculate_total_tds
    @net_commission = @total_commission - @total_tds
    @commission_count = @commission_data.total_count

    # Filter options for dropdowns
    @sub_agents = SubAgent.active.order(:first_name, :last_name)
    @distributors = Distributor.active.order(:first_name, :last_name)
    @insurance_companies = get_insurance_companies
    @policy_types = ['all', 'health', 'life', 'motor', 'other']
    @status_options = ['all', 'pending', 'paid', 'processing']

    respond_to do |format|
      format.html
      format.json { render json: commission_data_json }
    end
  end

  def export_modal
    render partial: 'export_modal', layout: false
  end

  def export_pdf
    @commission_data = fetch_commission_data(paginated: false)
    @selected_columns = params[:columns] || default_columns

    respond_to do |format|
      format.pdf do
        render pdf: "Commission_Report_#{Date.current.strftime('%Y%m%d')}",
               template: 'admin/reports/commission_reports_advanced/export_pdf',
               layout: 'pdf',
               page_size: 'A4',
               orientation: 'Landscape',
               margin: { top: 10, bottom: 10, left: 10, right: 10 }
      end
    end
  end

  def export_excel
    @commission_data = fetch_commission_data(paginated: false)
    @selected_columns = params[:columns] || default_columns

    respond_to do |format|
      format.xlsx do
        render xlsx: 'export_excel',
               filename: "Commission_Report_#{Date.current.strftime('%Y%m%d')}.xlsx"
      end
    end
  end

  def export_csv
    @commission_data = fetch_commission_data(paginated: false)
    @selected_columns = params[:columns] || default_columns

    respond_to do |format|
      format.csv do
        send_data generate_csv_data,
                  filename: "Commission_Report_#{Date.current.strftime('%Y%m%d')}.csv",
                  type: 'text/csv',
                  disposition: 'attachment'
      end
      format.html do
        send_data generate_csv_data,
                  filename: "Commission_Report_#{Date.current.strftime('%Y%m%d')}.csv",
                  type: 'text/csv',
                  disposition: 'attachment'
      end
      format.all do
        send_data generate_csv_data,
                  filename: "Commission_Report_#{Date.current.strftime('%Y%m%d')}.csv",
                  type: 'text/csv',
                  disposition: 'attachment'
      end
    end
  end

  def filter_data
    render json: {
      total_records: fetch_commission_data.count,
      total_commission: calculate_total_commission,
      total_tds: calculate_total_tds,
      net_commission: calculate_total_commission - calculate_total_tds
    }
  end

  private

  def fetch_commission_data(paginated: true)
    # Start with commission payouts query - no joins since customer is accessed through policy
    query = CommissionPayout.where(created_at: @start_date.beginning_of_day..@end_date.end_of_day)

    # Apply filters
    query = query.where(policy_type: @policy_type) if @policy_type && @policy_type != 'all'
    query = query.where(status: @status) if @status && @status != 'all'

    # For sub_agent and distributor filters, join with relevant policy tables
    if @sub_agent_id.present? || @distributor_id.present? || @insurance_company.present?
      case @policy_type
      when 'health'
        query = query.joins("LEFT JOIN health_insurances ON commission_payouts.policy_id = health_insurances.id AND commission_payouts.policy_type = 'health'")
        query = query.where('health_insurances.sub_agent_id = ?', @sub_agent_id) if @sub_agent_id.present?
        query = query.where('health_insurances.distributor_id = ?', @distributor_id) if @distributor_id.present?
        query = query.where('health_insurances.insurance_company_name ILIKE ?', "%#{@insurance_company}%") if @insurance_company.present?
      when 'life'
        query = query.joins("LEFT JOIN life_insurances ON commission_payouts.policy_id = life_insurances.id AND commission_payouts.policy_type = 'life'")
        query = query.where('life_insurances.sub_agent_id = ?', @sub_agent_id) if @sub_agent_id.present?
        query = query.where('life_insurances.distributor_id = ?', @distributor_id) if @distributor_id.present?
        query = query.where('life_insurances.insurance_company_name ILIKE ?', "%#{@insurance_company}%") if @insurance_company.present?
      when 'motor'
        query = query.joins("LEFT JOIN motor_insurances ON commission_payouts.policy_id = motor_insurances.id AND commission_payouts.policy_type = 'motor'")
        query = query.where('motor_insurances.sub_agent_id = ?', @sub_agent_id) if @sub_agent_id.present?
        query = query.where('motor_insurances.distributor_id = ?', @distributor_id) if @distributor_id.present?
        query = query.where('motor_insurances.insurance_company_name ILIKE ?', "%#{@insurance_company}%") if @insurance_company.present?
      when 'other'
        query = query.joins("LEFT JOIN other_insurances ON commission_payouts.policy_id = other_insurances.id AND commission_payouts.policy_type = 'other'")
        query = query.where('other_insurances.sub_agent_id = ?', @sub_agent_id) if @sub_agent_id.present?
        query = query.where('other_insurances.distributor_id = ?', @distributor_id) if @distributor_id.present?
        query = query.where('other_insurances.insurance_company_name ILIKE ?', "%#{@insurance_company}%") if @insurance_company.present?
      else
        # For 'all' policy types, create a complex union query
        health_ids = query_policy_ids('health', @sub_agent_id, @distributor_id, @insurance_company) if defined?(HealthInsurance)
        life_ids = query_policy_ids('life', @sub_agent_id, @distributor_id, @insurance_company) if defined?(LifeInsurance)
        motor_ids = query_policy_ids('motor', @sub_agent_id, @distributor_id, @insurance_company) if defined?(MotorInsurance)
        other_ids = query_policy_ids('other', @sub_agent_id, @distributor_id, @insurance_company) if defined?(OtherInsurance)

        all_matching_ids = [health_ids, life_ids, motor_ids, other_ids].compact.flatten
        query = query.where(id: all_matching_ids) if all_matching_ids.any?
      end
    end

    # Order by latest first
    query = query.order(created_at: :desc, id: :desc)

    paginated ? query : query.limit(10000) # Limit for exports
  end

  def calculate_total_commission
    fetch_commission_data(paginated: false).sum(:payout_amount) || 0
  end

  def calculate_total_tds
    fetch_commission_data(paginated: false).sum(:tds_amount) || 0
  end

  def query_policy_ids(policy_type, sub_agent_id, distributor_id, insurance_company)
    model_class = case policy_type
                  when 'health' then HealthInsurance
                  when 'life' then LifeInsurance
                  when 'motor' then MotorInsurance
                  when 'other' then OtherInsurance
                  else return []
                  end

    query = model_class.all
    query = query.where(sub_agent_id: sub_agent_id) if sub_agent_id.present?
    query = query.where(distributor_id: distributor_id) if distributor_id.present?
    query = query.where('insurance_company_name ILIKE ?', "%#{insurance_company}%") if insurance_company.present?

    # Return commission payout IDs for these policies
    CommissionPayout.where(policy_type: policy_type, policy_id: query.pluck(:id)).pluck(:id)
  rescue NameError => e
    Rails.logger.info "Model #{model_class} not defined: #{e.message}"
    []
  end

  def get_insurance_companies
    companies = []
    ['HealthInsurance', 'LifeInsurance', 'MotorInsurance', 'OtherInsurance'].each do |model_name|
      next unless defined?(model_name.constantize)
      companies += model_name.constantize.distinct.pluck(:insurance_company_name).compact
    end
    companies.uniq.sort
  end

  def commission_data_json
    {
      data: @commission_data.map do |commission|
        {
          id: commission.id,
          customer_name: commission.customer_name, # Using the method from CommissionPayout model
          policy_type: commission.policy_type&.titleize,
          policy_number: commission.policy_number, # Using the method from CommissionPayout model
          insurance_company: get_insurance_company(commission),
          payout_amount: commission.payout_amount,
          tds_amount: commission.tds_amount,
          net_amount: commission.net_amount, # Using the method from CommissionPayout model
          status: commission.status&.titleize,
          created_at: commission.created_at.strftime('%d/%m/%Y'),
          sub_agent_name: get_sub_agent_name(commission),
          distributor_name: get_distributor_name(commission)
        }
      end,
      pagination: {
        current_page: @commission_data.current_page,
        total_pages: @commission_data.total_pages,
        total_count: @commission_data.total_count
      },
      summary: {
        total_commission: @total_commission,
        total_tds: @total_tds,
        net_commission: @net_commission
      }
    }
  end

  def get_insurance_company(commission)
    commission.policy&.insurance_company_name
  end

  def get_sub_agent_name(commission)
    commission.policy&.sub_agent&.full_name
  end

  def get_distributor_name(commission)
    commission.policy&.distributor&.full_name
  end

  def default_columns
    %w[customer_name policy_type policy_number insurance_company payout_amount tds_amount net_amount status created_at]
  end

  def generate_csv_data
    require 'csv'

    CSV.generate(headers: true) do |csv|
      # Add headers
      headers = @selected_columns.map { |col| col.humanize }
      csv << headers

      # Add data rows
      @commission_data.each do |commission|
        row = []
        @selected_columns.each do |column|
          case column
          when 'customer_name'
            row << commission.customer_name
          when 'policy_type'
            row << commission.policy_type&.titleize
          when 'policy_number'
            row << commission.policy_number
          when 'insurance_company'
            row << get_insurance_company(commission)
          when 'payout_amount'
            row << commission.payout_amount
          when 'tds_amount'
            row << commission.tds_amount
          when 'net_amount'
            row << commission.net_amount
          when 'status'
            row << commission.status&.titleize
          when 'created_at'
            row << commission.created_at.strftime('%d/%m/%Y')
          when 'sub_agent_name'
            row << get_sub_agent_name(commission)
          when 'distributor_name'
            row << get_distributor_name(commission)
          end
        end
        csv << row
      end
    end
  end

  def set_filter_params
    @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : 30.days.ago.to_date
    @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current
    @policy_type = params[:policy_type] || 'all'
    @sub_agent_id = params[:sub_agent_id]
    @distributor_id = params[:distributor_id]
    @insurance_company = params[:insurance_company]
    @status = params[:status] || 'all'
  end

  def ensure_admin_or_authorized_user
    redirect_to root_path unless current_user.admin? || current_user.can_view_reports?
  end
end