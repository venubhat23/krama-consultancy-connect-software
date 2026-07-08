class Admin::Reports::BaseController < Admin::ApplicationController
  protected

  def apply_date_filters(scope, date_column = :created_at)
    scope = scope.where("#{date_column} >= ?", params[:start_date].to_date) if params[:start_date].present?
    scope = scope.where("#{date_column} <= ?", params[:end_date].to_date.end_of_day) if params[:end_date].present?
    scope
  end

  def apply_search_filters(scope, search_columns)
    return scope if params[:search].blank?

    search_term = "%#{params[:search]}%"
    conditions = search_columns.map { |col| "#{col} ILIKE ?" }
    values = [search_term] * search_columns.length

    scope.where(conditions.join(' OR '), *values)
  end

  def paginate_results(scope, per_page = 50)
    page = params[:page] || 1
    scope.page(page).per(per_page)
  end

  def export_to_csv(data, filename)
    require 'csv'

    respond_to do |format|
      format.csv do
        csv_data = CSV.generate(headers: true) do |csv|
          if data.any?
            csv << data.first.attributes.keys
            data.each { |record| csv << record.attributes.values }
          end
        end

        send_data csv_data,
          filename: "#{filename}_#{Date.current.strftime('%Y%m%d')}.csv",
          type: 'text/csv',
          disposition: 'attachment'
      end
    end
  end

  def calculate_statistics(data, numeric_columns = [])
    stats = {
      total_records: data.count,
      date_range: {
        start_date: params[:start_date] || 1.month.ago.to_date,
        end_date: params[:end_date] || Date.current
      }
    }

    numeric_columns.each do |column|
      stats["#{column}_total"] = data.sum(column)
      stats["#{column}_average"] = data.average(column)
      stats["#{column}_max"] = data.maximum(column)
      stats["#{column}_min"] = data.minimum(column)
    end

    stats
  end
end