require 'csv'
require 'roo'

module ImportService
  class AgencyImporter
    attr_reader :file, :imported_count, :skipped_count, :errors

    def initialize(file)
      @file = file
      @imported_count = 0
      @skipped_count = 0
      @errors = []
    end

    def import
      begin
        spreadsheet = open_spreadsheet(@file)
        header = spreadsheet.row(1)

        validate_headers(header)

        (2..spreadsheet.last_row).each do |i|
          row = Hash[[header, spreadsheet.row(i)].transpose]
          process_row(row, i)
        end

        {
          success: true,
          imported_count: @imported_count,
          skipped_count: @skipped_count,
          errors: @errors
        }
      rescue => e
        {
          success: false,
          error: e.message,
          imported_count: @imported_count,
          skipped_count: @skipped_count,
          errors: @errors
        }
      end
    end

    private

    def open_spreadsheet(file)
      case File.extname(file.original_filename)
      when '.csv'
        Roo::CSV.new(file.path)
      when '.xls'
        Roo::Excel.new(file.path)
      when '.xlsx'
        Roo::Excelx.new(file.path)
      else
        raise "Unknown file type: #{file.original_filename}"
      end
    end

    def validate_headers(header)
      required_headers = %w[broker_name broker_code]
      missing_headers = required_headers - header.map(&:to_s).map(&:downcase)

      if missing_headers.any?
        raise "Missing required headers: #{missing_headers.join(', ')}"
      end
    end

    def process_row(row, row_number)
      # Clean and normalize data
      agency_data = normalize_agency_data(row)

      # Validate row data
      if !valid_row?(agency_data, row_number)
        @skipped_count += 1
        return
      end

      # Check for duplicates
      if duplicate_agency?(agency_data)
        @errors << "Row #{row_number}: Agency with code '#{agency_data[:broker_code]}' already exists"
        @skipped_count += 1
        return
      end

      # Create agency/broker record (assuming we have a Broker model)
      # Note: This might need adjustment based on actual model structure
      begin
        if defined?(Broker)
          broker = Broker.new(agency_data)
          if broker.save
            @imported_count += 1
          else
            @errors << "Row #{row_number}: #{broker.errors.full_messages.join(', ')}"
            @skipped_count += 1
          end
        else
          @errors << "Row #{row_number}: Broker model not found"
          @skipped_count += 1
        end
      rescue => e
        @errors << "Row #{row_number}: #{e.message}"
        @skipped_count += 1
      end
    end

    def normalize_agency_data(row)
      {
        broker_name: row['broker_name']&.to_s&.strip,
        broker_code: row['broker_code']&.to_s&.upcase&.strip,
        agency_code: row['agency_code']&.to_s&.upcase&.strip,
        status: parse_status(row['status'])
      }.compact
    end

    def valid_row?(agency_data, row_number)
      # Check required fields
      if agency_data[:broker_name].blank?
        @errors << "Row #{row_number}: broker_name is required"
        return false
      end

      if agency_data[:broker_code].blank?
        @errors << "Row #{row_number}: broker_code is required"
        return false
      end

      true
    end

    def duplicate_agency?(agency_data)
      return false unless defined?(Broker)
      Broker.exists?(broker_code: agency_data[:broker_code])
    end

    def parse_status(status_string)
      return true if status_string.blank?

      case status_string.to_s.downcase.strip
      when 'active', 'true', '1', 'yes'
        true
      when 'inactive', 'false', '0', 'no'
        false
      else
        true # default to active
      end
    end
  end
end