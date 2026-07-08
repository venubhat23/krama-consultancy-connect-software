require 'csv'
require 'roo'

module ImportService
  class CustomerImporter
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
      required_headers = %w[customer_type mobile birth_date nominee_name nominee_relation nominee_date_of_birth]
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
      customer_data = normalize_customer_data(normalized_row)

      # Validate row data
      if !valid_row?(customer_data, row_number)
        @skipped_count += 1
        return
      end

      # Check for duplicates
      if duplicate_customer?(customer_data)
        @errors << "Row #{row_number}: Customer with email '#{customer_data[:email]}' or mobile '#{customer_data[:mobile]}' already exists"
        @skipped_count += 1
        return
      end

      # Create customer
      customer = Customer.new(customer_data)

      if customer.save
        @imported_count += 1
      else
        @errors << "Row #{row_number}: #{customer.errors.full_messages.join(', ')}"
        @skipped_count += 1
      end

    rescue => e
      @errors << "Row #{row_number}: #{e.message}"
      @skipped_count += 1
    end

    def normalize_customer_data(row)
      {
        customer_type: row['customer_type']&.to_s&.downcase,
        first_name: row['first_name']&.to_s&.strip,
        middle_name: row['middle_name']&.to_s&.strip,
        last_name: row['last_name']&.to_s&.strip,
        company_name: row['company_name']&.to_s&.strip,
        email: row['email']&.to_s&.downcase&.strip,
        mobile: row['mobile']&.to_s&.strip,
        gender: row['gender']&.to_s&.downcase,
        birth_date: parse_date(row['birth_date']),
        address: row['address']&.to_s&.strip,
        city: row['city']&.to_s&.strip,
        state: row['state']&.to_s&.strip,
        pincode: row['pincode']&.to_s&.strip,
        pan_no: row['pan_no']&.to_s&.upcase&.strip,
        gst_no: row['gst_no']&.to_s&.upcase&.strip,
        occupation: row['occupation']&.to_s&.strip,
        annual_income: parse_number(row['annual_income']),
        marital_status: row['marital_status']&.to_s&.downcase,
        # New mandatory nominee fields
        nominee_name: row['nominee_name']&.to_s&.strip,
        nominee_relation: row['nominee_relation']&.to_s&.downcase&.strip,
        nominee_date_of_birth: parse_date(row['nominee_date_of_birth']),
        # Additional optional fields
        education: row['education']&.to_s&.strip,
        height_feet: parse_number(row['height_feet']),
        weight_kg: parse_number(row['weight_kg']),
        birth_place: row['birth_place']&.to_s&.strip,
        business_job: row['business_job']&.to_s&.strip,
        job_name: row['job_name']&.to_s&.strip,
        type_of_duty: row['type_of_duty']&.to_s&.strip,
        business_name: row['business_name']&.to_s&.strip,
        status: true,
        added_by: 'bulk_import'
      }.compact
    end

    def valid_row?(customer_data, row_number)
      # Check customer type
      unless %w[individual corporate].include?(customer_data[:customer_type])
        @errors << "Row #{row_number}: Invalid customer_type. Must be 'individual' or 'corporate'"
        return false
      end

      # Check email format
      if customer_data[:email].present? && !customer_data[:email].match?(URI::MailTo::EMAIL_REGEXP)
        @errors << "Row #{row_number}: Invalid email format"
        return false
      end

      # Check mobile format (Indian mobile number)
      if customer_data[:mobile].present?
        clean_mobile = customer_data[:mobile].gsub(/\D/, '')
        unless clean_mobile.match?(/^[6-9]\d{9}$/)
          @errors << "Row #{row_number}: Invalid mobile number format"
          return false
        end
      end

      # Individual customer specific validation
      if customer_data[:customer_type] == 'individual'
        if customer_data[:first_name].blank?
          @errors << "Row #{row_number}: first_name is required for individual customers"
          return false
        end
      end

      # Corporate customer specific validation
      if customer_data[:customer_type] == 'corporate'
        if customer_data[:company_name].blank?
          @errors << "Row #{row_number}: company_name is required for corporate customers"
          return false
        end
      end

      true
    end

    def duplicate_customer?(customer_data)
      Customer.exists?(email: customer_data[:email]) ||
        Customer.exists?(mobile: customer_data[:mobile])
    end

    def parse_date(date_string)
      return nil if date_string.blank?

      begin
        Date.parse(date_string.to_s)
      rescue ArgumentError
        nil
      end
    end

    def parse_number(number_string)
      return nil if number_string.blank?

      begin
        number_string.to_s.gsub(/[^\d.]/, '').to_f
      rescue
        nil
      end
    end
  end
end