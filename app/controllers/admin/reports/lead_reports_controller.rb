class Admin::Reports::LeadReportsController < Admin::Reports::BaseController
  include ActionView::Helpers::NumberHelper

  def index
    # Default date range to last 1 month when no filter params are provided
    @filter_start_date = params[:start_date].presence || 1.month.ago.to_date.to_s
    @filter_end_date   = params[:end_date].presence   || Date.current.to_s
    @filter_stage      = params[:current_stage].to_s
    @filter_category   = params[:product_category].to_s

    filters = {
      start_date:       @filter_start_date,
      end_date:         @filter_end_date,
      current_stage:    @filter_stage,
      product_category: @filter_category
    }.reject { |_, v| v.blank? }

    @leads = build_lead_query(filters)

    # Saved reports listing
    @saved_reports = Report.where(report_type: 'leads')
                           .includes(:created_by)
                           .order(created_at: :desc)
                           .page(params[:page])
                           .per(10)

    @total_reports         = Report.where(report_type: 'leads').count
    @this_month_reports    = Report.where(report_type: 'leads')
                                   .where(created_at: Date.current.beginning_of_month..Date.current.end_of_month)
                                   .count
    @last_generated        = Report.where(report_type: 'leads').maximum(:created_at)
    @total_leads_from_reports = calculate_total_leads_from_reports

    load_form_data
  end

  def new
    # Load form data for dropdowns
    load_form_data
  end

  def create
    filters = report_params

    # Default the report name if blank
    if filters[:report_name].blank?
      filters[:report_name] = "Lead Report #{Date.current.strftime('%d %b %Y')}"
    end

    # Check download format selection
    download_format = params[:download_format]

    if download_format == 'preview'
      # Generate preview data
      preview_data = generate_preview_data(filters)
      render json: {
        status: 'success',
        preview_data: preview_data,
        filters: filters
      }
    elsif download_format.present? && params[:save_to_database].present?
      # Both save and download
      report_data = build_report_data(filters)
      report = save_report_to_database(report_data, filters)

      # Generate download immediately instead of storing in session
      case download_format
      when 'csv'
        csv_data = generate_csv_from_data(report_data, filters[:report_name], filters)
        send_data csv_data,
          filename: "#{filters[:report_name].parameterize}_#{Date.current.strftime('%Y%m%d')}.csv",
          type: 'text/csv',
          disposition: 'attachment'
        return
      when 'pdf'
        pdf_data = generate_pdf_from_data(report_data, filters[:report_name], filters)
        send_data pdf_data,
          filename: "#{filters[:report_name].parameterize}_#{Date.current.strftime('%Y%m%d')}.pdf",
          type: 'application/pdf',
          disposition: 'attachment'
        return
      end

      redirect_to admin_reports_lead_reports_path, notice: 'Lead report saved successfully!'
    elsif params[:save_to_database].present?
      # Only save to database
      report_data = build_report_data(filters)
      report = save_report_to_database(report_data, filters)
      redirect_to admin_reports_lead_reports_path,
                  notice: 'Lead report saved successfully!'
    elsif download_format.present?
      # Only download
      report_data = build_report_data(filters)

      case download_format
      when 'csv'
        csv_data = generate_csv_from_data(report_data, filters[:report_name], filters)

        send_data csv_data,
          filename: "#{filters[:report_name].parameterize}_#{Date.current.strftime('%Y%m%d')}.csv",
          type: 'text/csv',
          disposition: 'attachment'
        return
      end

      # No download, handle based on request type
      respond_to do |format|
        format.html { redirect_to admin_reports_lead_reports_path }
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
    redirect_to admin_reports_lead_reports_path,
                notice: 'Report deleted successfully!'
  end

  def export_csv
    @report = Report.find(params[:id])
    csv_data = generate_csv_from_report(@report)

    send_data csv_data,
      filename: "lead_report_#{@report.created_at.strftime('%Y%m%d_%H%M%S')}.csv",
      type: 'text/csv',
      disposition: 'attachment'
  end

  def preview
    filters = {
      start_date: params[:start_date].to_s,
      end_date: params[:end_date].to_s,
      current_stage: params[:current_stage].to_s,
      product_category: params[:product_category].to_s
    }.reject { |k, v| v.blank? }

    @preview_data = generate_preview_data(filters)

    render partial: 'preview_table', layout: false
  end


  private

  def report_params
    params.permit(:report_name, :start_date, :end_date, :current_stage, :product_category, :save_to_database, :download_format)
  end

  def load_form_data
    # Load lead stages for dropdown
    @lead_stages = Lead.current_stages.keys.map { |stage| [stage.humanize, stage] }
    @lead_stages.unshift(['All Stages', ''])

    # Load product categories
    @product_categories = Lead.product_categories.keys.map { |category| [category.humanize, category] }
    @product_categories.unshift(['All Categories', ''])
  end

  def generate_preview_data(filters)
    # Build the query based on filters
    leads = build_lead_query(filters)

    # Transform leads into preview data format
    leads.map do |lead|
      {
        'lead_details' => "#{lead.lead_id}<br/>#{lead.display_name}",
        'contact_information' => "#{lead.contact_number}<br/>#{lead.email || 'N/A'}",
        'referred_by_product_interest' => "#{lead.affiliate_name}<br/>#{lead.product_display_name}",
        'current_stage' => lead.current_stage&.humanize || 'N/A',
        'created_date' => lead.created_date&.strftime('%d %b %Y') || 'N/A'
      }
    end
  end

  def build_lead_query(filters)
    query = Lead.all

    # Apply date filters
    if filters[:start_date].present? && filters[:end_date].present?
      start_date = Date.parse(filters[:start_date])
      end_date = Date.parse(filters[:end_date])
      query = query.where(created_date: start_date..end_date)
    end

    # Apply stage filter
    if filters[:current_stage].present?
      query = query.where(current_stage: filters[:current_stage])
    end

    # Apply product category filter
    if filters[:product_category].present?
      query = query.where(product_category: filters[:product_category])
    end

    query.includes(:affiliate).order(:created_date)
  end

  def build_statistics_query(filters)
    query = Lead.all

    # Apply date filters
    if filters[:start_date].present? && filters[:end_date].present?
      start_date = Date.parse(filters[:start_date])
      end_date = Date.parse(filters[:end_date])
      query = query.where(created_date: start_date..end_date)
    end

    # Apply stage filter
    if filters[:current_stage].present?
      query = query.where(current_stage: filters[:current_stage])
    end

    # Apply product category filter
    if filters[:product_category].present?
      query = query.where(product_category: filters[:product_category])
    end

    query
  end

  def build_report_data(filters)
    leads = build_lead_query(filters)

    # Convert leads to report format
    lead_data = leads.map do |lead|
      {
        'lead_details' => "#{lead.lead_id} - #{lead.display_name}",
        'contact_information' => "#{lead.contact_number} - #{lead.email || 'N/A'}",
        'referred_by_product_interest' => "#{lead.affiliate_name} - #{lead.product_display_name}",
        'current_stage' => lead.current_stage&.humanize || 'N/A',
        'created_date' => lead.created_date&.strftime('%d %b %Y') || 'N/A',
        'lead_source' => lead.lead_source&.humanize || 'N/A',
        'product_category' => lead.product_category&.humanize || 'N/A',
        'product_subcategory' => lead.product_subcategory&.humanize || 'N/A'
      }
    end

    # Build fresh query without order for statistics to avoid GROUP BY issues
    stats_query = build_statistics_query(filters)

    # Calculate statistics
    statistics = {
      'total_leads' => stats_query.count,
      'leads_by_stage' => stats_query.group(:current_stage).count,
      'leads_by_source' => stats_query.group(:lead_source).count,
      'leads_by_product' => stats_query.group(:product_category).count,
      'converted_leads' => stats_query.where(current_stage: 'converted').count,
      'active_leads' => stats_query.where.not(current_stage: ['converted', 'lead_closed', 'not_interested']).count
    }

    {
      'leads' => lead_data,
      'statistics' => statistics,
      'filters' => filters
    }
  end

  def save_report_to_database(report_data, filters)
    Report.create!(
      report_type: 'leads',
      name: filters[:report_name],
      report_data: report_data,
      filters: filters.to_h,
      created_by: current_user
    )
  end

  def extract_preview_data_from_report(report)
    report.report_data['leads'] || []
  end

  def generate_csv_from_report(report)
    report_data = report.report_data || {}
    report_name = report.name || 'Lead Report'

    # Extract filters from report metadata if available
    filters = {
      start_date: report.filters&.dig('start_date') || 'All time',
      end_date: report.filters&.dig('end_date') || 'All time',
      current_stage: report.filters&.dig('current_stage') || 'All',
      product_category: report.filters&.dig('product_category') || 'All'
    }

    generate_csv_from_data(report_data, report_name, filters)
  end

  def calculate_total_leads_from_reports
    reports = Report.where(report_type: 'leads')
    total = 0
    reports.each do |report|
      lead_count = report.report_data&.dig('statistics', 'total_leads')
      total += lead_count.to_i if lead_count
    end
    total
  end

  def generate_csv_from_data(report_data, report_name, filters)
    require 'csv'

    leads = report_data['leads'] || []
    statistics = report_data['statistics'] || {}

    CSV.generate(headers: true) do |csv|
      # Add report header
      csv << ["Lead Report: #{report_name}"]
      csv << ["Generated on: #{Date.current.strftime('%d %b %Y')}"]
      csv << []

      # Add filters information
      csv << ["Report Filters:"]
      csv << ["Date Range:", "#{filters[:start_date]} to #{filters[:end_date]}"]
      csv << ["Current Stage:", filters[:current_stage] || "All Stages"]
      csv << ["Product Category:", filters[:product_category] || "All Categories"]
      csv << []

      # Add summary statistics
      csv << ["Summary Statistics:"]
      csv << ["Total Leads:", statistics['total_leads']]
      csv << ["Converted Leads:", statistics['converted_leads']]
      csv << ["Active Leads:", statistics['active_leads']]
      csv << []

      # Add leads data header
      csv << ["Lead Details", "Contact Information", "Referred By / Product Interest", "Current Stage", "Created Date", "Lead Source", "Product Category", "Product Subcategory"]

      # Add leads data
      leads.each do |lead|
        csv << [
          lead['lead_details'],
          lead['contact_information'],
          lead['referred_by_product_interest'],
          lead['current_stage'],
          lead['created_date'],
          lead['lead_source'],
          lead['product_category'],
          lead['product_subcategory']
        ]
      end
    end
  end

  def generate_pdf_from_data(report_data, report_name, filters)
    # Simple PDF generation - you can enhance this with a proper PDF library like Prawn
    # For now, return a basic text-based PDF content
    require 'csv'

    # Generate CSV content first, then convert to PDF-like format
    csv_content = generate_csv_from_data(report_data, report_name, filters)

    # This is a placeholder - in production you'd use a proper PDF library
    # For now, return the CSV content as plain text
    csv_content
  end
end