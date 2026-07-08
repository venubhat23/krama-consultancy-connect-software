class Admin::Reports::CommissionReportsController < Admin::Reports::BaseController
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

      when 'pdf'
        pdf_data = generate_pdf_from_data(download_data['report_data'], download_data['report_name'], download_data['filters'])

        respond_to do |format|
          format.html do
            send_data pdf_data,
              filename: "#{download_data['report_name'].parameterize}_#{Date.current.strftime('%Y%m%d')}.pdf",
              type: 'application/pdf',
              disposition: 'attachment'
          end
        end
        return
      end
    end

    # Normal index page rendering
    # Get saved reports for the listing
    @saved_reports = Report.where(report_type: 'commission')
                           .includes(:created_by)
                           .order(created_at: :desc)
                           .page(params[:page])
                           .per(10)

    # Calculate statistics
    @total_reports = Report.where(report_type: 'commission').count
    @this_month_reports = Report.where(report_type: 'commission')
                                .where(created_at: Date.current.beginning_of_month..Date.current.end_of_month)
                                .count
    @last_generated = Report.where(report_type: 'commission')
                            .maximum(:created_at)
    @total_commission = calculate_total_commission_from_reports

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
      start_date: params[:start_date].present? ? Date.parse(params[:start_date]) : 1.month.ago.to_date,
      end_date: params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current,
      payout_to: params[:payout_to].presence,
      policy_type: params[:policy_type].presence,
      status: params[:status].presence
    }.compact

    report_name = params[:report_name].presence || "Commission Report #{Date.current.strftime('%d %b %Y')}"

    # Generate report data with the same logic as preview
    report_data = generate_detailed_commission_report(filters)

    # Save to database if requested
    if params[:save_to_database] == "1"
      @report = Report.new(
        name: report_name,
        report_type: 'commission',
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
      elsif params[:export_format] == 'pdf'
        flash[:success] = "✅ Success! Report '#{report_name}' has been saved to database and PDF file will download shortly!"
      else
        flash[:success] = "✅ Report '#{report_name}' has been successfully saved to database!"
      end
    else
      if params[:export_format] == 'csv'
        flash[:success] = "✅ CSV file will download shortly!"
      elsif params[:export_format] == 'pdf'
        flash[:success] = "✅ PDF file will download shortly!"
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
        format.html { redirect_to admin_reports_commission_reports_path }
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
    redirect_to admin_reports_commission_reports_path,
                notice: 'Report deleted successfully!'
  end

  def export_csv
    @report = Report.find(params[:id])
    csv_data = generate_csv_from_report(@report)

    send_data csv_data,
      filename: "commission_report_#{@report.created_at.strftime('%Y%m%d_%H%M%S')}.csv",
      type: 'text/csv',
      disposition: 'attachment'
  end


  private

  def preview_params
    params.permit(:start_date, :end_date, :payout_to, :policy_type)
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
    # Start with base query depending on policy type filter
    if filters[:policy_type].present?
      case filters[:policy_type]
      when 'health'
        policies = HealthInsurance.includes(:customer)
      when 'motor'
        policies = MotorInsurance.includes(:customer)
      when 'life'
        policies = LifeInsurance.includes(:customer) if defined?(LifeInsurance)
      end
    else
      # Combine all policy types
      health_policies = HealthInsurance.includes(:customer)
      motor_policies = MotorInsurance.includes(:customer)

      # Apply date filters
      if filters[:start_date].present? && filters[:end_date].present?
        health_policies = health_policies.where(policy_booking_date: filters[:start_date]..filters[:end_date])
        motor_policies = motor_policies.where(policy_booking_date: filters[:start_date]..filters[:end_date])
      end

      # Combine and return results
      policies = []
      policies += health_policies.to_a
      policies += motor_policies.to_a

      return policies
    end

    # Apply date filters
    if filters[:start_date].present? && filters[:end_date].present?
      policies = policies.where(policy_booking_date: filters[:start_date]..filters[:end_date])
    end

    # Apply payout recipient filter if needed
    if filters[:payout_to].present?
      # Get policy IDs that have matching commission payouts
      policy_ids = CommissionPayout.where(payout_to: filters[:payout_to])
                                   .where(policy_type: filters[:policy_type] || ['health', 'motor', 'life'])
                                   .pluck(:policy_id)
                                   .uniq
      policies = policies.where(id: policy_ids)
    end

    # Apply status filter if needed
    if filters[:status].present?
      # Get policy IDs that have matching commission payouts with status
      policy_ids = CommissionPayout.where(status: filters[:status])
                                   .where(policy_type: filters[:policy_type] || ['health', 'motor', 'life'])
                                   .pluck(:policy_id)
                                   .uniq
      policies = policies.where(id: policy_ids)
    end

    policies
  end

  def build_policy_preview_data(policy)
    policy_type = policy.class.name.underscore.gsub('_insurance', '')

    # Get commission payouts for this policy
    payouts = CommissionPayout.where(policy_type: policy_type, policy_id: policy.id)

    {
      policy_number: policy.policy_number,
      policy_type: policy_type,
      customer_name: policy.customer&.display_name || 'N/A',
      insurance_company: policy.insurance_company_name || 'N/A',
      lead_id: policy.lead_id,
      premium_amount: policy.total_premium || 0,
      total_commission: calculate_total_commission(policy),
      main_agent_amount: get_main_agent_commission(policy),
      main_agent_percentage: policy.main_agent_commission_percentage || 0,
      main_agent_status: get_main_agent_status(payouts),
      paid_count: payouts.where(status: 'paid').count,
      total_recipients: payouts.count,
      paid_amount: payouts.where(status: 'paid').sum(:payout_amount),
      affiliate_amount: policy.sub_agent_commission_amount || 0,
      affiliate_percentage: policy.sub_agent_commission_percentage || 0,
      ambassador_amount: policy.ambassador_commission_amount || 0,
      ambassador_percentage: policy.ambassador_commission_percentage || 0,
      investor_amount: policy.investor_commission_amount || 0,
      investor_percentage: policy.investor_commission_percentage || 0,
      company_amount: policy.respond_to?(:company_expenses_amount) ? policy.company_expenses_amount : 0,
      company_percentage: policy.company_expenses_percentage || 0,
      distributor_amount: policy.respond_to?(:distributor_commission_amount) ? policy.distributor_commission_amount : 0,
      distributor_percentage: policy.respond_to?(:distributor_commission_percentage) ? policy.distributor_commission_percentage : 0
    }
  end

  def calculate_total_commission(policy)
    total = 0
    total += get_main_agent_commission(policy)
    total += policy.sub_agent_commission_amount || 0 if policy.respond_to?(:sub_agent_commission_amount)
    total += policy.ambassador_commission_amount || 0 if policy.respond_to?(:ambassador_commission_amount)
    total += policy.investor_commission_amount || 0 if policy.respond_to?(:investor_commission_amount)
    total += policy.distributor_commission_amount || 0 if policy.respond_to?(:distributor_commission_amount)

    # If no commission fields exist, calculate from payouts
    if total == 0
      payouts = CommissionPayout.where(policy_type: policy.class.name.underscore.gsub('_insurance', ''), policy_id: policy.id)
      total = payouts.sum(:payout_amount)
    end

    total
  end

  def get_main_agent_status(payouts)
    main_agent_payout = payouts.find { |p| p.payout_to == 'main_agent' }
    main_agent_payout&.status || 'pending'
  end

  def get_main_agent_commission(policy)
    # Different insurance types have different commission field names
    if policy.respond_to?(:main_agent_commission_amount) && policy.main_agent_commission_amount.present?
      policy.main_agent_commission_amount
    elsif policy.respond_to?(:commission_amount) && policy.commission_amount.present?
      policy.commission_amount
    else
      0
    end
  end

  def generate_detailed_commission_report(filters)
    preview_data = generate_preview_data(filters)

    {
      'statistics' => {
        'total_policies' => preview_data.size,
        'total_premium' => preview_data.sum { |p| p[:premium_amount] || 0 },
        'total_commission' => preview_data.sum { |p| p[:total_commission] || 0 },
        'total_paid' => preview_data.sum { |p| p[:paid_amount] || 0 }
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
    report_name = report.name || 'Commission Report'

    # Extract filters from report metadata if available
    filters = {
      start_date: report.filters&.dig('start_date') || 'All time',
      end_date: report.filters&.dig('end_date') || 'All time',
      payout_to: report.filters&.dig('payout_to') || 'All',
      policy_type: report.filters&.dig('policy_type') || 'All'
    }

    generate_csv_from_data(report_data, report_name, filters)
  end

  def calculate_total_commission_from_reports
    reports = Report.where(report_type: 'commission')
    total = 0
    reports.each do |report|
      commission = report.report_data&.dig('statistics', 'total_commission')
      total += commission.to_f if commission
    end
    total
  end

  def generate_csv_from_data(report_data, report_name, filters)
    require 'csv'

    policies = report_data['policies'] || []
    statistics = report_data['statistics'] || {}

    CSV.generate(headers: true) do |csv|
      # Add report header
      csv << ["Commission Report: #{report_name}"]
      csv << ["Generated on: #{Date.current.strftime('%d %b %Y')}"]
      csv << []

      # Add filters information
      csv << ["Report Filters:"]
      csv << ["Date Range:", "#{filters[:start_date]} to #{filters[:end_date]}"]
      csv << ["Policy Type:", filters[:policy_type] || "All Types"]
      csv << []

      # Add summary statistics
      csv << ["Summary Statistics:"]
      csv << ["Total Policies:", statistics['total_policies']]
      csv << ["Total Premium:", "Rs.#{statistics['total_premium']}"]
      csv << ["Total Commission:", "Rs.#{statistics['total_commission']}"]
      csv << ["Total Paid:", "Rs.#{statistics['total_paid']}"]
      csv << []

      # Add policy details header
      csv << ["Policy Details:"]
      csv << [
        'Policy Number', 'Policy Type', 'Customer Name', 'Insurance Company',
        'Lead ID', 'Premium Amount', 'Total Commission', 'Main Agent Commission',
        'Main Agent %', 'Affiliate Commission', 'Affiliate %', 'Ambassador Commission',
        'Ambassador %', 'Investor Commission', 'Investor %', 'Company Commission',
        'Company %', 'Distributor Commission', 'Distributor %', 'Paid Amount',
        'Transfer Status'
      ]

      policies.each do |policy|
        csv << [
          policy['policy_number'],
          policy['policy_type']&.capitalize,
          policy['customer_name'],
          policy['insurance_company'],
          policy['lead_id'],
          policy['premium_amount'],
          policy['total_commission'],
          policy['main_agent_amount'],
          policy['main_agent_percentage'],
          policy['affiliate_amount'],
          policy['affiliate_percentage'],
          policy['ambassador_amount'],
          policy['ambassador_percentage'],
          policy['investor_amount'],
          policy['investor_percentage'],
          policy['company_amount'],
          policy['company_percentage'],
          policy['distributor_amount'],
          policy['distributor_percentage'],
          policy['paid_amount'],
          "#{policy['paid_count']}/#{policy['total_recipients']}"
        ]
      end
    end
  end
end
