class Admin::Reports::UpcomingRenewalReportsController < Admin::Reports::BaseController
  include ActionView::Helpers::NumberHelper

  def index
    # Check for pending download and trigger it
    if session[:pending_download].present?
      download_data = session[:pending_download]
      session.delete(:pending_download)

      # Generate the file data
      case download_data['format']
      when 'csv'
        csv_data = generate_csv_from_data(download_data['report_data'], download_data['report_name'], download_data['filters'])

        respond_to do |format|
          format.html do
            send_data csv_data,
              filename: "#{download_data['report_name'].parameterize}_#{Date.current.strftime('%Y%m%d')}.csv",
              type: 'text/csv',
              disposition: 'attachment'
          end
        end
        return
      end
    end

    # Normal index page rendering
    # Get saved reports for the listing
    @saved_reports = Report.where(report_type: 'upcoming_renewal')
                           .includes(:created_by)
                           .order(created_at: :desc)
                           .page(params[:page])
                           .per(10)

    # Calculate statistics
    @total_reports = Report.where(report_type: 'upcoming_renewal').count
    @this_month_reports = Report.where(report_type: 'upcoming_renewal')
                                .where(created_at: Date.current.beginning_of_month..Date.current.end_of_month)
                                .count
    @last_generated = Report.where(report_type: 'upcoming_renewal')
                            .maximum(:created_at)
    @total_premium_value = calculate_total_premium_value_from_reports

    # Live: upcoming renewals for the next 30 days by default
    @renewal_days = (params[:renewal_days] || 30).to_i
    @renewal_start = Date.current
    @renewal_end   = @renewal_days.days.from_now.to_date
    @upcoming_policies = generate_preview_data(
      start_date: @renewal_start,
      end_date:   @renewal_end
    ).sort_by { |p| p[:days_until_renewal] }

    respond_to do |format|
      format.html
    end
  end

  def generate
    # Show the generate form page
  end

  def preview
    @preview_data = generate_preview_data(preview_params)

    render partial: 'preview_table', layout: false
  end

  def create_report
    filters = {
      start_date: params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current,
      end_date: params[:end_date].present? ? Date.parse(params[:end_date]) : 45.days.from_now.to_date,
      policy_type: params[:policy_type].presence,
      status: params[:status].presence
    }.compact

    report_name = params[:report_name].presence || "Upcoming Renewal Report #{Date.current.strftime('%d %b %Y')}"

    # Generate report data with the same logic as preview
    report_data = generate_detailed_renewal_report(filters)

    # Save to database if requested
    if params[:save_to_database] == "1"
      @report = Report.new(
        name: report_name,
        report_type: 'upcoming_renewal',
        filters: filters,
        report_data: report_data,
        status: true,
        generated_at: Time.current,
        created_by_id: current_user&.id
      )

      unless @report.save
        flash.now[:alert] = "Failed to save report: #{@report.errors.full_messages.join(', ')}"
        render :generate, status: :unprocessable_entity
        return
      end
    end

    # Set success message based on what was done
    if params[:save_to_database] == "1"
      if params[:export_format] == 'csv'
        flash[:success] = "✅ Success! Report '#{report_name}' has been saved to database and CSV file will download shortly!"
      else
        flash[:success] = "✅ Report '#{report_name}' has been successfully saved to database!"
      end
    else
      if params[:export_format] == 'csv'
        flash[:success] = "✅ CSV file will download shortly!"
      else
        flash[:info] = "Report generated successfully!"
      end
    end

    # Handle export format
    case params[:export_format]
    when 'csv'
      csv_data = generate_csv_from_data(report_data, report_name, filters)

      respond_to do |format|
        format.html do
          send_data csv_data,
            filename: "#{report_name.parameterize}_#{Date.current.strftime('%Y%m%d')}.csv",
            type: 'text/csv',
            disposition: 'attachment'
        end
        format.json do
          send_data csv_data,
            filename: "#{report_name.parameterize}_#{Date.current.strftime('%Y%m%d')}.csv",
            type: 'text/csv',
            disposition: 'attachment'
        end
      end

    else
      # No download, handle based on request type
      respond_to do |format|
        format.html { redirect_to admin_reports_upcoming_renewal_reports_path }
        format.json { render json: { status: 'success', message: 'Report generated successfully' } }
      end
    end
  end

  def show_saved_report
    @report = Report.find(params[:id])
    @preview_data = extract_preview_data_from_report(@report)
  end

  def destroy_saved_report
    @report = Report.find(params[:id])
    @report.destroy
    redirect_to admin_reports_upcoming_renewal_reports_path,
                notice: 'Report deleted successfully!'
  end

  def export_csv
    @report = Report.find(params[:id])
    csv_data = generate_csv_from_report(@report)

    send_data csv_data,
      filename: "upcoming_renewal_report_#{@report.created_at.strftime('%Y%m%d_%H%M%S')}.csv",
      type: 'text/csv',
      disposition: 'attachment'
  end

  private

  def preview_params
    params.permit(:start_date, :end_date, :policy_type, :status)
  end

  def generate_preview_data(filters)
    # Build the query based on filters
    policies = build_policy_query(filters)

    # Transform policies into preview data format
    policies.map do |policy|
      build_policy_preview_data(policy)
    end
  end

  def build_policy_query(filters)
    start_date = filters[:start_date].present? ? filters[:start_date].to_date : Date.current
    end_date = filters[:end_date].present? ? filters[:end_date].to_date : 45.days.from_now.to_date

    if filters[:policy_type].present?
      case filters[:policy_type]
      when 'health'
        policies = HealthInsurance.includes(:customer, :sub_agent)
                                  .where('policy_end_date BETWEEN ? AND ?', start_date, end_date)
        if filters[:status].present?
          case filters[:status]
          when 'due_soon'      then policies = policies.where('policy_end_date BETWEEN ? AND ?', Date.current, 7.days.from_now)
          when 'due_this_month' then policies = policies.where('policy_end_date BETWEEN ? AND ?', Date.current, Date.current.end_of_month)
          when 'due_next_month' then policies = policies.where('policy_end_date BETWEEN ? AND ?', Date.current.next_month.beginning_of_month, Date.current.next_month.end_of_month)
          end
        end
        return policies
      when 'motor'
        policies = MotorInsurance.includes(:customer, :sub_agent)
                                 .where('policy_end_date BETWEEN ? AND ?', start_date, end_date)
        if filters[:status].present?
          case filters[:status]
          when 'due_soon'      then policies = policies.where('policy_end_date BETWEEN ? AND ?', Date.current, 7.days.from_now)
          when 'due_this_month' then policies = policies.where('policy_end_date BETWEEN ? AND ?', Date.current, Date.current.end_of_month)
          when 'due_next_month' then policies = policies.where('policy_end_date BETWEEN ? AND ?', Date.current.next_month.beginning_of_month, Date.current.next_month.end_of_month)
          end
        end
        return policies
      when 'life'
        # Life insurance renewal = next premium due date (policy_end_date is 10-20 years away)
        return life_policies_due_in_range(start_date, end_date)
      end
    end

    # All types combined
    health_policies = HealthInsurance.includes(:customer, :sub_agent)
                                     .where('policy_end_date BETWEEN ? AND ?', start_date, end_date)
    motor_policies  = MotorInsurance.includes(:customer, :sub_agent)
                                    .where('policy_end_date BETWEEN ? AND ?', start_date, end_date)

    policies = health_policies.to_a + motor_policies.to_a
    policies += life_policies_due_in_range(start_date, end_date)
    policies
  end

  # Returns life insurance policies whose next premium payment falls within [start_date, end_date].
  # Uses payment cycle from policy_start_date rather than policy_end_date.
  def life_policies_due_in_range(start_date, end_date)
    LifeInsurance.includes(:customer, :sub_agent)
                 .where('policy_end_date >= ?', Date.current)
                 .select do |p|
                   due = next_life_premium_due(p)
                   due.present? && due.between?(start_date, end_date)
                 end
  end

  def build_policy_preview_data(policy)
    policy_type = policy.class.name.underscore.gsub('_insurance', '')

    # For life insurance use next premium due date; for others use policy_end_date
    effective_renewal_date = if policy_type == 'life'
                               next_life_premium_due(policy) || policy.policy_end_date
                             else
                               policy.policy_end_date
                             end

    days_until_renewal = effective_renewal_date ? (effective_renewal_date - Date.current).to_i : 0

    status = if effective_renewal_date <= 7.days.from_now
               'Due Soon'
             elsif effective_renewal_date <= Date.current.end_of_month
               'Due This Month'
             elsif effective_renewal_date <= Date.current.next_month.end_of_month
               'Due Next Month'
             else
               'Future Renewal'
             end

    {
      id: policy.id,
      policy_number: policy.policy_number,
      policy_type: policy_type,
      customer_name: policy.customer&.display_name || 'N/A',
      customer_email: policy.customer&.email,
      customer_mobile: policy.customer&.mobile,
      insurance_company: policy.insurance_company_name || 'N/A',
      policy_start_date: policy.policy_start_date,
      policy_end_date: effective_renewal_date,
      days_until_renewal: days_until_renewal,
      premium_amount: policy.total_premium || 0,
      sum_insured: policy.try(:sum_insured) || policy.try(:total_idv) || 0,
      status: status,
      affiliate: policy.sub_agent&.display_name || 'Self',
      policy_object: policy
    }
  end

  def generate_detailed_renewal_report(filters)
    preview_data = generate_preview_data(filters)

    {
      'statistics' => {
        'total_policies' => preview_data.size,
        'total_premium' => preview_data.sum { |p| p[:premium_amount] || 0 },
        'total_sum_insured' => preview_data.sum { |p| p[:sum_insured] || 0 },
        'due_soon_count' => preview_data.count { |p| p[:status] == 'Due Soon' },
        'due_this_month_count' => preview_data.count { |p| p[:status] == 'Due This Month' },
        'due_next_month_count' => preview_data.count { |p| p[:status] == 'Due Next Month' }
      },
      'policies' => preview_data,
      'filters' => filters
    }
  end

  def extract_preview_data_from_report(report)
    report.report_data['policies'] || []
  end

  def generate_csv_from_report(report)
    report_data = report.report_data || {}
    report_name = report.name || 'Upcoming Renewal Report'

    # Extract filters from report metadata if available
    filters = {
      start_date: report.filters&.dig('start_date') || 'All time',
      end_date: report.filters&.dig('end_date') || 'All time',
      policy_type: report.filters&.dig('policy_type') || 'All',
      status: report.filters&.dig('status') || 'All'
    }

    generate_csv_from_data(report_data, report_name, filters)
  end

  def calculate_total_premium_value_from_reports
    reports = Report.where(report_type: 'upcoming_renewal')
    total = 0
    reports.each do |report|
      premium = report.report_data&.dig('statistics', 'total_premium')
      total += premium.to_f if premium
    end
    total
  end

  def generate_csv_from_data(report_data, report_name, filters)
    require 'csv'

    policies = report_data['policies'] || []
    statistics = report_data['statistics'] || {}

    CSV.generate(headers: true) do |csv|
      # Add report header
      csv << ["Upcoming Renewal Report: #{report_name}"]
      csv << ["Generated on: #{Date.current.strftime('%d %b %Y')}"]
      csv << []

      # Add filters information
      csv << ["Report Filters:"]
      csv << ["Date Range:", "#{filters[:start_date]} to #{filters[:end_date]}"]
      csv << ["Policy Type:", filters[:policy_type] || "All Types"]
      csv << ["Status:", filters[:status] || "All Status"]
      csv << []

      # Add summary statistics
      csv << ["Summary Statistics:"]
      csv << ["Total Policies:", statistics['total_policies']]
      csv << ["Total Premium:", "Rs.#{statistics['total_premium']}"]
      csv << ["Total Sum Insured:", "Rs.#{statistics['total_sum_insured']}"]
      csv << ["Due Soon:", statistics['due_soon_count']]
      csv << ["Due This Month:", statistics['due_this_month_count']]
      csv << ["Due Next Month:", statistics['due_next_month_count']]
      csv << []

      # Add policy details header
      csv << ["Policy Details:"]
      csv << [
        'Policy Number', 'Policy Type', 'Customer Name', 'Customer Email', 'Customer Mobile',
        'Insurance Company', 'Policy Start Date', 'Policy End Date', 'Days Until Renewal',
        'Premium Amount', 'Sum Insured', 'Status', 'Affiliate'
      ]

      policies.each do |policy|
        csv << [
          policy['policy_number'],
          policy['policy_type']&.capitalize,
          policy['customer_name'],
          policy['customer_email'],
          policy['customer_mobile'],
          policy['insurance_company'],
          policy['policy_start_date'],
          policy['policy_end_date'],
          policy['days_until_renewal'],
          policy['premium_amount'],
          policy['sum_insured'],
          policy['status'],
          policy['affiliate']
        ]
      end
    end
  end

  # Returns the next future premium due date for a life insurance policy
  # by advancing from policy_start_date in payment_mode intervals.
  def next_life_premium_due(policy)
    return nil if policy.policy_start_date.blank? || policy.payment_mode.blank?
    calculate_next_premium_due(policy.policy_start_date, policy.payment_mode)
  end

  def calculate_next_premium_due(start_date, payment_mode)
    return nil if start_date.nil? || payment_mode.nil?
    return nil if ['single', 'one time', 'lump sum'].include?(payment_mode.to_s.downcase)

    interval = case payment_mode.to_s.downcase
               when 'monthly'                    then 1.month
               when 'quarterly'                  then 3.months
               when 'half-yearly', 'half yearly' then 6.months
               when 'yearly'                     then 1.year
               else return nil
               end

    due = start_date
    safety = 0
    while due <= Date.current && safety < 300
      due += interval
      safety += 1
    end
    due
  end
end