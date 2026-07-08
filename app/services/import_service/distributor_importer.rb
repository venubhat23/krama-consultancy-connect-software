require 'csv'
require 'roo'

module ImportService
  class DistributorImporter
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
      required_headers = %w[first_name last_name email mobile]
      # Normalize headers by removing asterisks and converting to lowercase
      normalized_headers = header.map(&:to_s).map(&:downcase).map { |h| h.gsub('*', '') }
      missing_headers = required_headers - normalized_headers

      if missing_headers.any?
        raise "Missing required headers: #{missing_headers.join(', ')}"
      end
    end

    def process_row(row, row_number)
      # Normalize row keys by removing asterisks (from required field markers)
      normalized_row = {}
      row.each do |key, value|
        normalized_key = key.to_s.gsub('*', '')
        normalized_row[normalized_key] = value
      end

      # Clean and normalize data
      distributor_data = normalize_distributor_data(normalized_row)

      # Validate row data
      if !valid_row?(distributor_data, row_number)
        @skipped_count += 1
        return
      end

      # Check for duplicates
      if duplicate_distributor?(distributor_data)
        @errors << "Row #{row_number}: Distributor with email '#{distributor_data[:email]}' or mobile '#{distributor_data[:mobile]}' already exists"
        @skipped_count += 1
        return
      end

      # Create distributor
      distributor = Distributor.new(distributor_data)

      if distributor.save
        @imported_count += 1
      else
        @errors << "Row #{row_number}: #{distributor.errors.full_messages.join(', ')}"
        @skipped_count += 1
      end

    rescue => e
      @errors << "Row #{row_number}: #{e.message}"
      @skipped_count += 1
    end

    def normalize_distributor_data(row)
      # Get distributor role_id - find or create distributor role
      distributor_role = Role.find_or_create_by(name: 'distributor') do |role|
        role.description = 'Distributor Role'
      end

      # Map account_no field
      account_no = row['account_no'] || row['account_number']

      {
        first_name: row['first_name']&.to_s&.strip,
        middle_name: row['middle_name']&.to_s&.strip,
        last_name: row['last_name']&.to_s&.strip,
        email: row['email']&.to_s&.downcase&.strip,
        mobile: row['mobile']&.to_s&.strip,
        gender: row['gender']&.to_s&.titleize,
        birth_date: parse_date(row['birth_date']),
        address: row['address']&.to_s&.strip,
        state: row['state']&.to_s&.strip,
        city: row['city']&.to_s&.strip,
        pan_no: row['pan_no']&.to_s&.upcase&.strip,
        account_holder_name: row['account_holder_name']&.to_s&.strip,
        account_no: account_no&.to_s&.strip,
        ifsc_code: row['ifsc_code']&.to_s&.upcase&.strip,
        account_type: row['account_type']&.to_s&.titleize,
        role_id: distributor_role.id,
        status: parse_status(row['status'])
      }.compact
    end

    def valid_row?(distributor_data, row_number)
      # Check email format
      if distributor_data[:email].present? && !distributor_data[:email].match?(URI::MailTo::EMAIL_REGEXP)
        @errors << "Row #{row_number}: Invalid email format"
        return false
      end

      # Check mobile format (Indian mobile number)
      if distributor_data[:mobile].present?
        clean_mobile = distributor_data[:mobile].gsub(/\D/, '')
        unless clean_mobile.match?(/^[6-9]\d{9}$/)
          @errors << "Row #{row_number}: Invalid mobile number format"
          return false
        end
      end

      # Check required fields
      if distributor_data[:first_name].blank?
        @errors << "Row #{row_number}: first_name is required"
        return false
      end

      if distributor_data[:last_name].blank?
        @errors << "Row #{row_number}: last_name is required"
        return false
      end

      if distributor_data[:email].blank?
        @errors << "Row #{row_number}: email is required"
        return false
      end

      if distributor_data[:mobile].blank?
        @errors << "Row #{row_number}: mobile is required"
        return false
      end

      # Validate gender if present
      if distributor_data[:gender].present? && !%w[Male Female Other].include?(distributor_data[:gender])
        @errors << "Row #{row_number}: Invalid gender. Must be 'Male', 'Female', or 'Other'"
        return false
      end

      # Validate account type if present
      if distributor_data[:account_type].present? && !%w[Savings Current Salary].include?(distributor_data[:account_type])
        @errors << "Row #{row_number}: Invalid account_type. Must be 'Savings', 'Current', or 'Salary'"
        return false
      end

      true
    end

    def duplicate_distributor?(distributor_data)
      Distributor.exists?(email: distributor_data[:email]) ||
        Distributor.exists?(mobile: distributor_data[:mobile])
    end

    def parse_date(date_string)
      return nil if date_string.blank?

      begin
        Date.parse(date_string.to_s)
      rescue ArgumentError
        nil
      end
    end

    def parse_status(status_string)
      return 0 if status_string.blank? # Default to active (0)

      case status_string.to_s.downcase.strip
      when 'active', '1', 'true'
        0 # active
      when 'inactive', '0', 'false'
        1 # inactive
      else
        0 # default to active
      end
    end
  end
end