class Admin::ImportsController < Admin::ApplicationController
  require 'csv'

  # Skip CSRF token verification for import endpoints that handle file uploads
  skip_before_action :verify_authenticity_token, only: [:customers, :customers_preview, :sub_agents, :sub_agents_preview, :distributors, :distributors_preview, :health_insurances, :health_insurances_preview, :life_insurances, :life_insurances_preview, :motor_insurances, :motor_insurances_preview]

  def index
    @import_stats = {
      total_imports: get_total_imports_count,
      successful_imports: get_successful_imports_count,
      failed_imports: get_failed_imports_count,
      last_import: get_last_import_date
    }
  end

  def customers_form
    # Show customer import form
    respond_to do |format|
      format.html # customers_form.html.erb
      format.json { render json: { error: 'HTML format required for this page' } }
    end
  end

  # POST /admin/imports/customers_preview
  def customers_preview
    uploaded_file = params[:file]

    if uploaded_file.blank?
      render json: { success: false, error: 'Please select a file to import.' }
      return
    end

    begin
      require 'csv'

      Rails.logger.info "Processing file: #{uploaded_file.original_filename}"
      Rails.logger.info "File path: #{uploaded_file.path}"
      Rails.logger.info "File size: #{uploaded_file.size}"

      preview_results = []
      row_index = 0
      total_rows_processed = 0

      # Detect CSV encoding and parse
      file_content = File.read(uploaded_file.path)

      # Try UTF-8 first, then fallback to other encodings
      begin
        file_content = file_content.force_encoding('UTF-8')
        csv_data = CSV.parse(file_content, headers: true, skip_blanks: true)
      rescue CSV::MalformedCSVError, Encoding::UndefinedConversionError
        # Try with different encoding
        file_content = file_content.force_encoding('ISO-8859-1').encode('UTF-8')
        csv_data = CSV.parse(file_content, headers: true, skip_blanks: true)
      end

      Rails.logger.info "CSV headers: #{csv_data.headers}"
      Rails.logger.info "Total CSV rows: #{csv_data.length}"

      # Pre-fetch all existing mobile numbers to avoid N+1 queries
      # Only query if we have rows to validate
      existing_mobiles = Set.new
      if csv_data.length > 0
        all_mobiles = []
        csv_data.each do |row|
          mobile = (row['mobile*'] || row['mobile'])&.to_s&.strip
          if mobile.present?
            clean_mobile = mobile.gsub(/\D/, '')
            all_mobiles << mobile
            all_mobiles << clean_mobile if clean_mobile != mobile
          end
        end

        if all_mobiles.any?
          # Use select to reduce memory usage for large customer tables
          existing_mobiles = Customer.select(:mobile).where(mobile: all_mobiles.uniq).pluck(:mobile).to_set
        end
      end

      csv_data.each_with_index do |row, index|
        row_index = index + 1
        total_rows_processed += 1

        # Skip completely empty rows
        row_data = row.to_h
        next if row_data.values.all? { |v| v.nil? || v.strip.empty? }

        Rails.logger.info "Processing row #{row_index}: #{row_data}" if row_index <= 3 # Log first 3 rows

        validation_errors = validate_customer_row_optimized(row_data, row_index, existing_mobiles)

        preview_results << {
          row: row_index,
          data: row_data,
          errors: validation_errors,
          valid: validation_errors.empty?
        }
      end

      Rails.logger.info "Preview results: #{preview_results.count} rows processed"

      render json: {
        success: true,
        preview: preview_results,
        total_rows: preview_results.count,
        valid_rows: preview_results.count { |r| r[:valid] },
        invalid_rows: preview_results.count { |r| !r[:valid] },
        debug: {
          original_rows: total_rows_processed,
          headers: csv_data.headers,
          file_size: uploaded_file.size
        }
      }

    rescue => e
      Rails.logger.error "Customer preview error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: {
        success: false,
        error: "Error reading file: #{e.message}. Please check the format and try again.",
        debug: {
          error_class: e.class.name,
          file_name: uploaded_file.original_filename,
          file_size: uploaded_file.size
        }
      }
    end
  end

  def sub_agents_preview
    return render json: { error: 'File required' }, status: :bad_request unless params[:file].present?

    uploaded_file = params[:file]

    begin
      require 'csv'

      Rails.logger.info "Processing sub-agents file: #{uploaded_file.original_filename}"
      Rails.logger.info "File path: #{uploaded_file.path}"
      Rails.logger.info "File size: #{uploaded_file.size}"

      preview_results = []
      row_index = 0
      total_rows_processed = 0

      # Detect CSV encoding and parse
      file_content = File.read(uploaded_file.path)

      # Try UTF-8 first, then fallback to other encodings
      begin
        file_content = file_content.force_encoding('UTF-8')
        csv_data = CSV.parse(file_content, headers: true, skip_blanks: true)
      rescue CSV::MalformedCSVError, Encoding::UndefinedConversionError
        # Try with different encoding
        file_content = file_content.force_encoding('ISO-8859-1').encode('UTF-8')
        csv_data = CSV.parse(file_content, headers: true, skip_blanks: true)
      end

      Rails.logger.info "CSV headers: #{csv_data.headers}"
      Rails.logger.info "Total CSV rows: #{csv_data.length}"

      # Normalize headers by removing asterisks
      normalized_headers = csv_data.headers.map { |h| h.to_s.gsub('*', '') }

      # Preview first 10 rows or all rows if less than 10
      preview_count = [csv_data.length, 10].min

      csv_data.first(preview_count).each_with_index do |row, index|
        row_index = index + 1
        total_rows_processed += 1

        # Skip completely empty rows
        row_data = row.to_h
        next if row_data.values.all? { |v| v.nil? || v.to_s.strip.empty? }

        # Normalize row data (remove asterisks from keys)
        normalized_row = {}
        row_data.each do |key, value|
          normalized_key = key.to_s.gsub('*', '')
          normalized_row[normalized_key] = value
        end

        # Basic validation for sub-agents
        validation_errors = []

        # Check required fields
        validation_errors << "First name is required" if normalized_row['first_name'].to_s.strip.empty?
        validation_errors << "Last name is required" if normalized_row['last_name'].to_s.strip.empty?
        validation_errors << "Mobile is required" if normalized_row['mobile'].to_s.strip.empty?

        # Mobile validation
        mobile = normalized_row['mobile'].to_s.strip
        if mobile.present?
          clean_mobile = mobile.gsub(/\D/, '')
          validation_errors << "Mobile must be exactly 10 digits" if clean_mobile.length != 10
        end

        # Email validation
        email = normalized_row['email'].to_s.strip
        if email.present? && !email.match?(URI::MailTo::EMAIL_REGEXP)
          validation_errors << "Invalid email format"
        end

        preview_results << {
          row: row_index,
          data: normalized_row,
          errors: validation_errors,
          valid: validation_errors.empty?
        }
      end

      Rails.logger.info "Preview results: #{preview_results.count} rows processed"

      render json: {
        success: true,
        preview: preview_results,
        headers: normalized_headers,
        total_rows: csv_data.length,
        valid_rows: preview_results.count { |r| r[:valid] },
        invalid_rows: preview_results.count { |r| !r[:valid] },
        file_name: uploaded_file.original_filename,
        file_size: uploaded_file.size
      }
    rescue => e
      Rails.logger.error "Sub-agents preview error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: {
        success: false,
        error: "Error processing file: #{e.message}",
        file_name: uploaded_file.original_filename,
        file_size: uploaded_file.size
      }
    end
  end

  def distributors_preview
    return render json: { error: 'File required' }, status: :bad_request unless params[:file].present?

    uploaded_file = params[:file]

    begin
      require 'csv'

      Rails.logger.info "Processing distributors file: #{uploaded_file.original_filename}"
      Rails.logger.info "File path: #{uploaded_file.path}"
      Rails.logger.info "File size: #{uploaded_file.size}"

      preview_results = []
      row_index = 0
      total_rows_processed = 0

      # Detect CSV encoding and parse
      file_content = File.read(uploaded_file.path)

      # Try UTF-8 first, then fallback to other encodings
      begin
        file_content = file_content.force_encoding('UTF-8')
        csv_data = CSV.parse(file_content, headers: true, skip_blanks: true)
      rescue CSV::MalformedCSVError, Encoding::UndefinedConversionError
        # Try with different encoding
        file_content = file_content.force_encoding('ISO-8859-1').encode('UTF-8')
        csv_data = CSV.parse(file_content, headers: true, skip_blanks: true)
      end

      Rails.logger.info "CSV headers: #{csv_data.headers}"
      Rails.logger.info "Total CSV rows: #{csv_data.length}"

      # Normalize headers by removing asterisks
      normalized_headers = csv_data.headers.map { |h| h.to_s.gsub('*', '') }

      # Preview first 10 rows or all rows if less than 10
      preview_count = [csv_data.length, 10].min

      csv_data.first(preview_count).each_with_index do |row, index|
        row_index = index + 1
        total_rows_processed += 1

        # Skip completely empty rows
        row_data = row.to_h
        next if row_data.values.all? { |v| v.nil? || v.to_s.strip.empty? }

        # Normalize row data (remove asterisks from keys)
        normalized_row = {}
        row_data.each do |key, value|
          normalized_key = key.to_s.gsub('*', '')
          normalized_row[normalized_key] = value
        end

        # Basic validation for distributors
        validation_errors = []

        # Check required fields
        validation_errors << "First name is required" if normalized_row['first_name'].to_s.strip.empty?
        validation_errors << "Last name is required" if normalized_row['last_name'].to_s.strip.empty?
        validation_errors << "Email is required" if normalized_row['email'].to_s.strip.empty?
        validation_errors << "Mobile is required" if normalized_row['mobile'].to_s.strip.empty?

        # Mobile validation
        mobile = normalized_row['mobile'].to_s.strip
        if mobile.present?
          clean_mobile = mobile.gsub(/\D/, '')
          validation_errors << "Mobile must be exactly 10 digits" if clean_mobile.length != 10
        end

        # Email validation
        email = normalized_row['email'].to_s.strip
        if email.present? && !email.match?(URI::MailTo::EMAIL_REGEXP)
          validation_errors << "Invalid email format"
        end

        preview_results << {
          row: row_index,
          data: normalized_row,
          errors: validation_errors,
          valid: validation_errors.empty?
        }
      end

      Rails.logger.info "Preview results: #{preview_results.count} rows processed"

      render json: {
        success: true,
        preview: preview_results,
        headers: normalized_headers,
        total_rows: csv_data.length,
        valid_rows: preview_results.count { |r| r[:valid] },
        invalid_rows: preview_results.count { |r| !r[:valid] },
        file_name: uploaded_file.original_filename,
        file_size: uploaded_file.size
      }
    rescue => e
      Rails.logger.error "Distributors preview error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: {
        success: false,
        error: "Error processing file: #{e.message}",
        file_name: uploaded_file.original_filename,
        file_size: uploaded_file.size
      }
    end
  end

  def health_insurances_preview
    return render json: { error: 'File required' }, status: :bad_request unless params[:file].present?

    uploaded_file = params[:file]

    begin
      require 'csv'

      Rails.logger.info "Processing health insurances file: #{uploaded_file.original_filename}"
      Rails.logger.info "File path: #{uploaded_file.path}"
      Rails.logger.info "File size: #{uploaded_file.size}"

      preview_results = []
      row_index = 0
      total_rows_processed = 0

      # Detect CSV encoding and parse
      file_content = File.read(uploaded_file.path)

      # Try UTF-8 first, then fallback to other encodings
      begin
        file_content = file_content.force_encoding('UTF-8')
        csv_data = CSV.parse(file_content, headers: true, skip_blanks: true)
      rescue CSV::MalformedCSVError, Encoding::UndefinedConversionError
        # Try with different encoding
        file_content = file_content.force_encoding('ISO-8859-1').encode('UTF-8')
        csv_data = CSV.parse(file_content, headers: true, skip_blanks: true)
      end

      Rails.logger.info "CSV headers: #{csv_data.headers}"
      Rails.logger.info "Total CSV rows: #{csv_data.length}"

      # Normalize headers by removing asterisks
      normalized_headers = csv_data.headers.map { |h| h.to_s.gsub('*', '') }

      # Preview first 10 rows or all rows if less than 10
      preview_count = [csv_data.length, 10].min

      csv_data.first(preview_count).each_with_index do |row, index|
        row_index = index + 1
        total_rows_processed += 1

        # Skip completely empty rows
        row_data = row.to_h
        next if row_data.values.all? { |v| v.nil? || v.to_s.strip.empty? }

        # Normalize row data (remove asterisks from keys)
        normalized_row = {}
        row_data.each do |key, value|
          normalized_key = key.to_s.gsub('*', '')
          normalized_row[normalized_key] = value
        end

        # Basic validation for health insurance
        validation_errors = []

        # Check required fields
        validation_errors << "Customer email is required" if normalized_row['customer_email'].to_s.strip.empty?
        customer_email_val = normalized_row['customer_email'].to_s.strip
        if customer_email_val.present? && !customer_email_val.match?(URI::MailTo::EMAIL_REGEXP)
          validation_errors << "Customer email format is invalid"
        end
        validation_errors << "Policy number is required" if normalized_row['policy_number'].to_s.strip.empty?
        validation_errors << "Insurance company name is required" if normalized_row['insurance_company_name'].to_s.strip.empty?

        # Validate policy type
        policy_type = normalized_row['policy_type'].to_s.strip.downcase
        if policy_type.present? && !['new', 'renewal'].include?(policy_type)
          validation_errors << "Policy type must be 'New' or 'Renewal'"
        end

        # Validate insurance type
        insurance_type = normalized_row['insurance_type'].to_s.strip.downcase
        if insurance_type.present? && !['individual', 'family floater'].include?(insurance_type)
          validation_errors << "Insurance type must be 'Individual' or 'Family Floater'"
        end

        # Validate payment mode
        payment_mode = normalized_row['payment_mode'].to_s.strip.downcase
        if payment_mode.present? && !['yearly', 'half yearly', 'quarterly', 'monthly'].include?(payment_mode)
          validation_errors << "Payment mode must be 'Yearly', 'Half Yearly', 'Quarterly', or 'Monthly'"
        end

        # Validate numeric fields
        ['sum_insured', 'net_premium', 'gst_percentage', 'total_premium'].each do |field|
          value = normalized_row[field].to_s.strip
          if value.present? && !value.match?(/^\d+(\.\d+)?$/)
            validation_errors << "#{field.humanize} must be a valid number"
          end
        end

        # Validate dates
        ['policy_booking_date', 'policy_start_date', 'policy_end_date'].each do |date_field|
          date_value = normalized_row[date_field].to_s.strip
          if date_value.present?
            begin
              Date.parse(date_value)
            rescue
              validation_errors << "#{date_field.humanize} must be a valid date"
            end
          end
        end

        preview_results << {
          row: row_index,
          data: normalized_row,
          errors: validation_errors,
          valid: validation_errors.empty?
        }
      end

      Rails.logger.info "Preview results: #{preview_results.count} rows processed"

      render json: {
        success: true,
        preview: preview_results,
        headers: normalized_headers,
        total_rows: csv_data.length,
        valid_rows: preview_results.count { |r| r[:valid] },
        invalid_rows: preview_results.count { |r| !r[:valid] },
        file_name: uploaded_file.original_filename,
        file_size: uploaded_file.size
      }
    rescue => e
      Rails.logger.error "Health insurances preview error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: {
        success: false,
        error: "Error processing file: #{e.message}",
        file_name: uploaded_file.original_filename,
        file_size: uploaded_file.size
      }
    end
  end

  def life_insurances_preview
    return render json: { error: 'File required' }, status: :bad_request unless params[:file].present?

    uploaded_file = params[:file]

    begin
      require 'csv'

      Rails.logger.info "Processing life insurances file: #{uploaded_file.original_filename}"
      Rails.logger.info "File path: #{uploaded_file.path}"
      Rails.logger.info "File size: #{uploaded_file.size}"

      preview_results = []
      row_index = 0
      total_rows_processed = 0

      # Detect CSV encoding and parse
      file_content = File.read(uploaded_file.path)

      # Try UTF-8 first, then fallback to other encodings
      begin
        file_content = file_content.force_encoding('UTF-8')
        csv_data = CSV.parse(file_content, headers: true, skip_blanks: true)
      rescue CSV::MalformedCSVError, Encoding::UndefinedConversionError
        # Try with different encoding
        file_content = file_content.force_encoding('ISO-8859-1').encode('UTF-8')
        csv_data = CSV.parse(file_content, headers: true, skip_blanks: true)
      end

      Rails.logger.info "CSV headers: #{csv_data.headers}"
      Rails.logger.info "Total CSV rows: #{csv_data.length}"

      # Normalize headers by removing asterisks
      normalized_headers = csv_data.headers.map { |h| h.to_s.gsub('*', '') }

      # Preview first 10 rows or all rows if less than 10
      preview_count = [csv_data.length, 10].min

      csv_data.first(preview_count).each_with_index do |row, index|
        row_index = index + 1
        total_rows_processed += 1

        # Skip completely empty rows
        row_data = row.to_h
        next if row_data.values.all? { |v| v.nil? || v.to_s.strip.empty? }

        # Normalize row data (remove asterisks from keys)
        normalized_row = {}
        row_data.each do |key, value|
          normalized_key = key.to_s.gsub('*', '')
          normalized_row[normalized_key] = value
        end

        # Basic validation for life insurance
        validation_errors = []

        # Check required fields
        validation_errors << "Customer email is required" if normalized_row['customer_email'].to_s.strip.empty?
        customer_email_val = normalized_row['customer_email'].to_s.strip
        if customer_email_val.present? && !customer_email_val.match?(URI::MailTo::EMAIL_REGEXP)
          validation_errors << "Customer email format is invalid"
        end
        validation_errors << "Policy number is required" if normalized_row['policy_number'].to_s.strip.empty?
        validation_errors << "Insurance company name is required" if normalized_row['insurance_company_name'].to_s.strip.empty?

        # Validate policy type
        policy_type = normalized_row['policy_type'].to_s.strip.downcase
        if policy_type.present? && !['new', 'renewal'].include?(policy_type)
          validation_errors << "Policy type must be 'New' or 'Renewal'"
        end

        # Validate payment mode
        payment_mode = normalized_row['payment_mode'].to_s.strip.downcase
        if payment_mode.present? && !['yearly', 'half yearly', 'quarterly', 'monthly'].include?(payment_mode)
          validation_errors << "Payment mode must be 'Yearly', 'Half Yearly', 'Quarterly', or 'Monthly'"
        end

        # Validate numeric fields
        ['sum_insured', 'net_premium', 'first_year_gst_percentage', 'total_premium', 'policy_term'].each do |field|
          value = normalized_row[field].to_s.strip
          if value.present? && !value.match?(/^\d+(\.\d+)?$/)
            validation_errors << "#{field.humanize} must be a valid number"
          end
        end

        # Validate policy term range
        policy_term = normalized_row['policy_term'].to_s.strip
        if policy_term.present? && policy_term.match?(/^\d+$/)
          term_value = policy_term.to_i
          if term_value < 1 || term_value > 100
            validation_errors << "Policy term must be between 1 and 100 years"
          end
        end

        # Validate dates
        ['policy_booking_date', 'policy_start_date', 'policy_end_date'].each do |date_field|
          date_value = normalized_row[date_field].to_s.strip
          if date_value.present?
            begin
              Date.parse(date_value)
            rescue
              validation_errors << "#{date_field.humanize} must be a valid date"
            end
          end
        end

        preview_results << {
          row: row_index,
          data: normalized_row,
          errors: validation_errors,
          valid: validation_errors.empty?
        }
      end

      Rails.logger.info "Preview results: #{preview_results.count} rows processed"

      render json: {
        success: true,
        preview: preview_results,
        headers: normalized_headers,
        total_rows: csv_data.length,
        valid_rows: preview_results.count { |r| r[:valid] },
        invalid_rows: preview_results.count { |r| !r[:valid] },
        file_name: uploaded_file.original_filename,
        file_size: uploaded_file.size
      }
    rescue => e
      Rails.logger.error "Life insurances preview error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: {
        success: false,
        error: "Error processing file: #{e.message}",
        file_name: uploaded_file.original_filename,
        file_size: uploaded_file.size
      }
    end
  end

  def motor_insurances_preview
    return render json: { error: 'File required' }, status: :bad_request unless params[:file].present?

    uploaded_file = params[:file]

    begin
      require 'csv'

      Rails.logger.info "Processing motor insurances file: #{uploaded_file.original_filename}"
      Rails.logger.info "File path: #{uploaded_file.path}"
      Rails.logger.info "File size: #{uploaded_file.size}"

      preview_results = []
      row_index = 0
      total_rows_processed = 0

      # Detect CSV encoding and parse
      file_content = File.read(uploaded_file.path)

      # Try UTF-8 first, then fallback to other encodings
      begin
        file_content = file_content.force_encoding('UTF-8')
        csv_data = CSV.parse(file_content, headers: true, skip_blanks: true)
      rescue CSV::MalformedCSVError, Encoding::UndefinedConversionError
        # Try with different encoding
        file_content = file_content.force_encoding('ISO-8859-1').encode('UTF-8')
        csv_data = CSV.parse(file_content, headers: true, skip_blanks: true)
      end

      Rails.logger.info "CSV headers: #{csv_data.headers}"
      Rails.logger.info "Total CSV rows: #{csv_data.length}"

      # Normalize headers by removing asterisks
      normalized_headers = csv_data.headers.map { |h| h.to_s.gsub('*', '') }

      # Preview first 10 rows or all rows if less than 10
      preview_count = [csv_data.length, 10].min

      csv_data.first(preview_count).each_with_index do |row, index|
        row_index = index + 1
        total_rows_processed += 1

        # Skip completely empty rows
        row_data = row.to_h
        next if row_data.values.all? { |v| v.nil? || v.to_s.strip.empty? }

        # Normalize row data (remove asterisks from keys)
        normalized_row = {}
        row_data.each do |key, value|
          normalized_key = key.to_s.gsub('*', '')
          normalized_row[normalized_key] = value
        end

        # Basic validation for motor insurance
        validation_errors = []

        # Check required fields
        validation_errors << "Customer email is required" if normalized_row['customer_email'].to_s.strip.empty?
        customer_email_val = normalized_row['customer_email'].to_s.strip
        if customer_email_val.present? && !customer_email_val.match?(URI::MailTo::EMAIL_REGEXP)
          validation_errors << "Customer email format is invalid"
        end
        validation_errors << "Policy number is required" if normalized_row['policy_number'].to_s.strip.empty?
        validation_errors << "Insurance company name is required" if normalized_row['insurance_company_name'].to_s.strip.empty?
        validation_errors << "Vehicle type is required" if normalized_row['vehicle_type'].to_s.strip.empty?
        validation_errors << "Registration number is required" if normalized_row['registration_number'].to_s.strip.empty?
        validation_errors << "Vehicle IDV is required" if normalized_row['vehicle_idv'].to_s.strip.empty?

        # Validate vehicle type
        vehicle_type = normalized_row['vehicle_type'].to_s.strip
        if vehicle_type.present? && !['New Vehicle', 'Old Vehicle'].include?(vehicle_type)
          validation_errors << "Vehicle type must be 'New Vehicle' or 'Old Vehicle'"
        end

        # Validate class of vehicle
        class_of_vehicle = normalized_row['class_of_vehicle'].to_s.strip
        if class_of_vehicle.present? && !['Private Car', 'Two Wheeler', 'Goods Vehicle', 'Taxi', 'Bus'].include?(class_of_vehicle)
          validation_errors << "Class of vehicle must be 'Private Car', 'Two Wheeler', 'Goods Vehicle', 'Taxi', or 'Bus'"
        end

        # Validate insurance type
        insurance_type_val = normalized_row['insurance_type'].to_s.strip
        if insurance_type_val.present? && !['Comprehensive', 'Third Party', 'Own Damage'].include?(insurance_type_val)
          validation_errors << "Insurance type must be 'Comprehensive', 'Third Party', or 'Own Damage'"
        end

        # Validate numeric fields
        ['vehicle_idv', 'net_premium', 'gst_percentage', 'total_premium'].each do |field|
          value = normalized_row[field].to_s.strip
          if value.present? && !value.match?(/^\d+(\.\d+)?$/)
            validation_errors << "#{field.humanize} must be a valid number"
          end
        end

        # Validate dates
        ['policy_booking_date', 'policy_start_date', 'policy_end_date'].each do |date_field|
          date_value = normalized_row[date_field].to_s.strip
          if date_value.present?
            begin
              Date.parse(date_value)
            rescue
              validation_errors << "#{date_field.humanize} must be a valid date"
            end
          end
        end

        # Validate registration number format (basic Indian format)
        registration_number = normalized_row['registration_number'].to_s.strip.upcase
        if registration_number.present? && !registration_number.match?(/^[A-Z]{2}\d{1,2}[A-Z]{1,2}\d{1,4}$/)
          validation_errors << "Registration number format is invalid (should be like MH01AB1234)"
        end

        preview_results << {
          row: row_index,
          data: normalized_row,
          errors: validation_errors,
          valid: validation_errors.empty?
        }
      end

      Rails.logger.info "Preview results: #{preview_results.count} rows processed"

      render json: {
        success: true,
        preview: preview_results,
        headers: normalized_headers,
        total_rows: csv_data.length,
        valid_rows: preview_results.count { |r| r[:valid] },
        invalid_rows: preview_results.count { |r| !r[:valid] },
        file_name: uploaded_file.original_filename,
        file_size: uploaded_file.size
      }
    rescue => e
      Rails.logger.error "Motor insurances preview error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: {
        success: false,
        error: "Error processing file: #{e.message}",
        file_name: uploaded_file.original_filename,
        file_size: uploaded_file.size
      }
    end
  end

  def sub_agents
    return render json: { error: 'File required' }, status: :bad_request unless params[:file].present?

    uploaded_file = params[:file]

    begin
      importer = ImportService::SubAgentImporter.new(uploaded_file)
      result = importer.import

      if result[:success]
        respond_to do |format|
          format.html { redirect_to admin_imports_sub_agents_form_path, notice: "Sub-agents imported successfully! #{result[:imported_count]} imported, #{result[:skipped_count]} skipped." }
          format.json { render json: result }
        end
      else
        respond_to do |format|
          format.html { redirect_to admin_imports_sub_agents_form_path, alert: "Import failed: #{result[:error]}" }
          format.json { render json: result }
        end
      end
    rescue => e
      respond_to do |format|
        format.html { redirect_to admin_imports_sub_agents_form_path, alert: "Import failed: #{e.message}" }
        format.json { render json: { success: false, error: e.message } }
      end
    end
  end

  def sub_agents_form
    # Show sub-agent import form
    respond_to do |format|
      format.html # sub_agents_form.html.erb
      format.json { render json: { error: 'HTML format required for this page' } }
    end
  end

  def distributors_form
    # Show distributor import form
    respond_to do |format|
      format.html # distributors_form.html.erb
      format.json { render json: { error: 'HTML format required for this page' } }
    end
  end

  def health_insurances_form
    # Show health insurance import form
    respond_to do |format|
      format.html # health_insurances_form.html.erb
      format.json { redirect_to health_insurances_form_admin_imports_path }
    end
  end

  def life_insurances_form
    # Show life insurance import form
    respond_to do |format|
      format.html # life_insurances_form.html.erb
      format.json { render json: { error: 'HTML format required for this page' } }
    end
  end

  def motor_insurances_form
    # Show motor insurance import form
    respond_to do |format|
      format.html # motor_insurances_form.html.erb
      format.json { render json: { error: 'HTML format required for this page' } }
    end
  end

  # POST /admin/import/customers
  def customers
    uploaded_file = params[:file]

    Rails.logger.info "Customer import started with file: #{uploaded_file&.original_filename}"
    Rails.logger.info "Request format: #{request.format}"
    Rails.logger.info "Request headers: Accept = #{request.headers['Accept']}"

    if uploaded_file.blank?
      Rails.logger.error "No file uploaded"
      respond_to do |format|
        format.html { redirect_back fallback_location: admin_imports_path, alert: 'Please select a file to import.' }
        format.json { render json: { success: false, error: 'Please select a file to import.' } }
      end
      return
    end

    begin
      Rails.logger.info "Starting import process..."
      import_result = ImportService::CustomerImporter.new(uploaded_file).import
      Rails.logger.info "Import result: #{import_result.inspect}"

      respond_to do |format|
        if import_result[:success]
          success_message = "Successfully imported #{import_result[:imported_count]} customers. #{import_result[:skipped_count]} records were skipped due to validation errors."
          Rails.logger.info "Import successful: #{success_message}"

          format.html { redirect_to admin_customers_path, notice: success_message }
          format.json {
            response_data = {
              success: true,
              message: success_message,
              imported_count: import_result[:imported_count],
              skipped_count: import_result[:skipped_count],
              total_count: import_result[:imported_count] + import_result[:skipped_count]
            }
            Rails.logger.info "Sending JSON response: #{response_data.inspect}"
            render json: response_data
          }
        else
          error_message = "Import failed: #{import_result[:error]}"
          Rails.logger.error error_message

          format.html { redirect_back fallback_location: admin_imports_path, alert: error_message }
          format.json { render json: { success: false, error: error_message } }
        end
      end
    rescue => e
      Rails.logger.error "Customer import exception: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      respond_to do |format|
        format.html { redirect_back fallback_location: admin_imports_path, alert: 'An error occurred during import. Please check your file format and try again.' }
        format.json { render json: { success: false, error: "An error occurred during import: #{e.message}" } }
      end
    end
  end

  # POST /admin/import/sub_agents
  def sub_agents
    uploaded_file = params[:file]

    Rails.logger.info "Sub-agent import started with file: #{uploaded_file&.original_filename}"
    Rails.logger.info "Request format: #{request.format}"

    if uploaded_file.blank?
      respond_to do |format|
        format.html { redirect_back fallback_location: admin_imports_path, alert: 'Please select a file to import.' }
        format.json { render json: { success: false, error: 'Please select a file to import.' } }
      end
      return
    end

    begin
      import_result = ImportService::SubAgentImporter.new(uploaded_file).import
      Rails.logger.info "Import result: #{import_result.inspect}"

      respond_to do |format|
        if import_result[:success]
          success_message = "Successfully imported #{import_result[:imported_count]} affiliates. #{import_result[:skipped_count]} records were skipped due to validation errors."
          Rails.logger.info "Import successful: #{success_message}"

          format.html { redirect_to admin_sub_agents_path, notice: success_message }
          format.json {
            render json: {
              success: true,
              message: success_message,
              imported_count: import_result[:imported_count],
              skipped_count: import_result[:skipped_count],
              total_count: import_result[:imported_count] + import_result[:skipped_count],
              errors: import_result[:errors] || [],
              redirect_url: admin_sub_agents_path
            }
          }
        else
          error_message = "Import failed: #{import_result[:error]}"
          Rails.logger.error error_message

          format.html { redirect_back fallback_location: admin_imports_path, alert: error_message }
          format.json { render json: { success: false, error: error_message } }
        end
      end
    rescue => e
      Rails.logger.error "Affiliate import error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      respond_to do |format|
        format.html { redirect_back fallback_location: admin_imports_path, alert: 'An error occurred during import. Please check your file format and try again.' }
        format.json { render json: { success: false, error: "An error occurred during import: #{e.message}" } }
      end
    end
  end

  # POST /admin/import/distributors
  def distributors
    uploaded_file = params[:file]

    Rails.logger.info "Distributor import started with file: #{uploaded_file&.original_filename}"
    Rails.logger.info "Request format: #{request.format}"

    if uploaded_file.blank?
      respond_to do |format|
        format.html { redirect_back fallback_location: admin_imports_path, alert: 'Please select a file to import.' }
        format.json { render json: { success: false, error: 'Please select a file to import.' } }
      end
      return
    end

    begin
      import_result = ImportService::DistributorImporter.new(uploaded_file).import
      Rails.logger.info "Import result: #{import_result.inspect}"

      respond_to do |format|
        if import_result[:success]
          success_message = "Successfully imported #{import_result[:imported_count]} distributors. #{import_result[:skipped_count]} records were skipped due to validation errors."
          Rails.logger.info "Import successful: #{success_message}"

          format.html { redirect_to admin_distributors_path, notice: success_message }
          format.json {
            render json: {
              success: true,
              message: success_message,
              imported_count: import_result[:imported_count],
              skipped_count: import_result[:skipped_count],
              total_count: import_result[:imported_count] + import_result[:skipped_count],
              errors: import_result[:errors] || [],
              redirect_url: admin_distributors_path
            }
          }
        else
          error_message = "Import failed: #{import_result[:error]}"
          Rails.logger.error error_message

          format.html { redirect_back fallback_location: admin_imports_path, alert: error_message }
          format.json { render json: { success: false, error: error_message } }
        end
      end
    rescue => e
      Rails.logger.error "Distributor import error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      respond_to do |format|
        format.html { redirect_back fallback_location: admin_imports_path, alert: 'An error occurred during import. Please check your file format and try again.' }
        format.json { render json: { success: false, error: "An error occurred during import: #{e.message}" } }
      end
    end
  end

  # POST /admin/import/health_insurances
  def health_insurances
    uploaded_file = params[:file]

    Rails.logger.info "Health insurance import started with file: #{uploaded_file&.original_filename}"
    Rails.logger.info "Request format: #{request.format}"

    if uploaded_file.blank?
      respond_to do |format|
        format.html { redirect_back fallback_location: admin_imports_path, alert: 'Please select a file to import.' }
        format.json { render json: { success: false, error: 'Please select a file to import.' } }
      end
      return
    end

    begin
      import_result = ImportService::HealthInsuranceImporter.new(uploaded_file).import
      Rails.logger.info "Import result: #{import_result.inspect}"

      respond_to do |format|
        if import_result[:success]
          success_message = "Successfully imported #{import_result[:imported_count]} health insurance policies. #{import_result[:skipped_count]} records were skipped due to validation errors."
          Rails.logger.info "Import successful: #{success_message}"

          format.html { redirect_to admin_health_insurances_path, notice: success_message }
          format.json {
            render json: {
              success: true,
              message: success_message,
              imported_count: import_result[:imported_count],
              skipped_count: import_result[:skipped_count],
              total_count: import_result[:imported_count] + import_result[:skipped_count],
              errors: import_result[:errors] || [],
              redirect_url: admin_health_insurances_path
            }
          }
        else
          error_message = "Import failed: #{import_result[:error]}"
          Rails.logger.error error_message

          format.html { redirect_back fallback_location: admin_imports_path, alert: error_message }
          format.json { render json: { success: false, error: error_message } }
        end
      end
    rescue => e
      Rails.logger.error "Health insurance import error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      respond_to do |format|
        format.html { redirect_back fallback_location: admin_imports_path, alert: 'An error occurred during import. Please check your file format and try again.' }
        format.json { render json: { success: false, error: "An error occurred during import: #{e.message}" } }
      end
    end
  end

  # POST /admin/import/life_insurances
  def life_insurances
    uploaded_file = params[:file]

    Rails.logger.info "Life insurance import started with file: #{uploaded_file&.original_filename}"
    Rails.logger.info "Request format: #{request.format}"

    if uploaded_file.blank?
      respond_to do |format|
        format.html { redirect_back fallback_location: admin_imports_path, alert: 'Please select a file to import.' }
        format.json { render json: { success: false, error: 'Please select a file to import.' } }
      end
      return
    end

    begin
      import_result = ImportService::LifeInsuranceImporter.new(uploaded_file).import
      Rails.logger.info "Import result: #{import_result.inspect}"

      respond_to do |format|
        if import_result[:success]
          success_message = "Successfully imported #{import_result[:imported_count]} life insurance policies. #{import_result[:skipped_count]} records were skipped due to validation errors."
          Rails.logger.info "Import successful: #{success_message}"

          format.html { redirect_to admin_life_insurances_path, notice: success_message }
          format.json {
            render json: {
              success: true,
              message: success_message,
              imported_count: import_result[:imported_count],
              skipped_count: import_result[:skipped_count],
              total_count: import_result[:imported_count] + import_result[:skipped_count],
              errors: import_result[:errors] || [],
              redirect_url: admin_life_insurances_path
            }
          }
        else
          error_message = "Import failed: #{import_result[:error]}"
          Rails.logger.error error_message

          format.html { redirect_back fallback_location: admin_imports_path, alert: error_message }
          format.json { render json: { success: false, error: error_message } }
        end
      end
    rescue => e
      Rails.logger.error "Life insurance import error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      respond_to do |format|
        format.html { redirect_back fallback_location: admin_imports_path, alert: 'An error occurred during import. Please check your file format and try again.' }
        format.json { render json: { success: false, error: "An error occurred during import: #{e.message}" } }
      end
    end
  end

  # POST /admin/import/motor_insurances
  def motor_insurances
    uploaded_file = params[:file]

    Rails.logger.info "Motor insurance import started with file: #{uploaded_file&.original_filename}"
    Rails.logger.info "Request format: #{request.format}"

    if uploaded_file.blank?
      respond_to do |format|
        format.html { redirect_back fallback_location: admin_imports_path, alert: 'Please select a file to import.' }
        format.json { render json: { success: false, error: 'Please select a file to import.' } }
      end
      return
    end

    begin
      import_result = ImportService::MotorInsuranceImporter.new(uploaded_file).import
      Rails.logger.info "Import result: #{import_result.inspect}"

      respond_to do |format|
        if import_result[:success]
          success_message = "Successfully imported #{import_result[:imported_count]} motor insurance policies. #{import_result[:skipped_count]} records were skipped due to validation errors."
          Rails.logger.info "Import successful: #{success_message}"

          format.html { redirect_to admin_motor_insurances_path, notice: success_message }
          format.json {
            render json: {
              success: true,
              message: success_message,
              imported_count: import_result[:imported_count],
              skipped_count: import_result[:skipped_count],
              total_count: import_result[:imported_count] + import_result[:skipped_count],
              errors: import_result[:errors] || [],
              redirect_url: admin_motor_insurances_path
            }
          }
        else
          error_message = "Import failed: #{import_result[:error]}"
          Rails.logger.error error_message

          format.html { redirect_back fallback_location: admin_imports_path, alert: error_message }
          format.json { render json: { success: false, error: error_message } }
        end
      end
    rescue => e
      Rails.logger.error "Motor insurance import error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      respond_to do |format|
        format.html { redirect_back fallback_location: admin_imports_path, alert: 'An error occurred during import. Please check your file format and try again.' }
        format.json { render json: { success: false, error: "An error occurred during import: #{e.message}" } }
      end
    end
  end

  # POST /admin/import/agencies (keeping existing for compatibility)
  def agencies
    uploaded_file = params[:file]

    if uploaded_file.blank?
      redirect_back fallback_location: admin_users_path, alert: 'Please select a file to import.'
      return
    end

    begin
      import_result = ImportService::AgencyImporter.new(uploaded_file).import

      if import_result[:success]
        redirect_to admin_users_path, notice: "Successfully imported #{import_result[:imported_count]} agencies."
      else
        redirect_back fallback_location: admin_imports_path, alert: "Import failed: #{import_result[:error]}"
      end
    rescue => e
      Rails.logger.error "Agency import error: #{e.message}"
      redirect_back fallback_location: admin_users_path, alert: 'An error occurred during import. Please check your file format and try again.'
    end
  end

  def download_template
    template_type = params[:template_type]

    case template_type
    when 'customers'
      send_customer_template
    when 'sub_agents'
      send_sub_agent_template
    when 'distributors'
      send_distributor_template
    when 'health_insurances'
      send_health_insurance_template
    when 'life_insurances'
      send_life_insurance_template
    when 'motor_insurances'
      send_motor_insurance_template
    else
      redirect_to admin_imports_path, alert: 'Invalid template type'
    end
  end


  # Template download methods
  def send_customer_template
    template_type = params[:client_type] || 'both'

    case template_type
    when 'individual'
      send_individual_customer_template
    when 'corporate'
      send_corporate_customer_template
    else
      send_both_customer_template
    end
  end

  def send_individual_customer_template
    csv_data = CSV.generate(headers: true) do |csv|
      csv << [
        'customer_type*', 'first_name*', 'middle_name', 'last_name*', 'mobile*',
        'email', 'gender', 'birth_date*', 'marital_status', 'address', 'city', 'state',
        'pincode', 'pan_no', 'nominee_name*', 'nominee_relation*', 'nominee_date_of_birth*',
        'occupation', 'annual_income', 'education', 'height_feet', 'weight_kg',
        'birth_place', 'business_job', 'job_name', 'type_of_duty', 'sub_agent_name', 'status'
      ]
      # Sample row 1
      csv << [
        'individual', 'John', 'Kumar', 'Doe', '9876543210',
        'john.doe@example.com', 'male', '1990-01-01', 'married', '123 Main St', 'Mumbai', 'Maharashtra',
        '400001', 'ABCDE1234F', 'Jane Doe', 'spouse', '1992-05-15',
        'Software Engineer', '800000', 'Graduate', '5.8', '70',
        'Mumbai', 'Private Job', 'Senior Developer', 'Office Work', 'Agent Name', 'true'
      ]
      # Sample row 2
      csv << [
        'individual', 'Priya', '', 'Sharma', '9876543211',
        'priya.sharma@example.com', 'female', '1985-05-15', 'single', '456 Park Road', 'Delhi', 'Delhi',
        '110001', 'BCDEF2345G', 'Ram Sharma', 'father', '1960-03-20',
        'Teacher', '500000', 'Post Graduate', '5.4', '55',
        'Delhi', 'Government Job', 'Assistant Professor', 'Teaching', '', 'true'
      ]
      # Empty row for user data
      csv << [
        'individual', '', '', '', '',
        '', '', '', '', '', '', '',
        '', '', '', '', '',
        '', '', '', '', '',
        '', '', '', '', '', 'true'
      ]
    end

    send_data csv_data, filename: 'individual_customers_template.csv', type: 'text/csv'
  end

  def send_corporate_customer_template
    csv_data = CSV.generate(headers: true) do |csv|
      csv << [
        'customer_type*', 'company_name*', 'mobile*', 'email*', 'gst_no*',
        'birth_date*', 'address', 'city', 'state', 'pincode', 'pan_no',
        'nominee_name*', 'nominee_relation*', 'nominee_date_of_birth*',
        'annual_income', 'business_name', 'sub_agent_name', 'status'
      ]
      # Sample row 1
      csv << [
        'corporate', 'ABC Company Ltd', '9876543211', 'contact@abc.com', '22ABCDE1234F1Z5',
        '2010-01-01', '456 Business Park', 'Delhi', 'Delhi', '110001', 'ABCDE1234F',
        'John Doe', 'other', '1980-01-01',
        '5000000', 'ABC Business Ventures', 'Agent Name', 'true'
      ]
      # Sample row 2
      csv << [
        'corporate', 'XYZ Enterprises Pvt Ltd', '9876543212', 'info@xyz.com', '27BCDEF2345G1Z6',
        '2015-05-15', '789 Industrial Area', 'Mumbai', 'Maharashtra', '400001', 'BCDEF2345G',
        'Jane Smith', 'other', '1985-03-10',
        '3000000', 'XYZ Manufacturing', '', 'true'
      ]
      # Empty row for user data
      csv << [
        'corporate', '', '', '', '',
        '', '', '', '', '', '',
        '', '', '',
        '', '', '', 'true'
      ]
    end

    send_data csv_data, filename: 'corporate_customers_template.csv', type: 'text/csv'
  end

  def send_both_customer_template
    csv_data = CSV.generate(headers: true) do |csv|
      csv << [
        'customer_type*', 'first_name', 'middle_name', 'last_name', 'company_name',
        'mobile*', 'email', 'gender', 'birth_date*', 'marital_status', 'address', 'city', 'state',
        'pincode', 'pan_no', 'gst_no', 'nominee_name*', 'nominee_relation*', 'nominee_date_of_birth*',
        'occupation', 'annual_income', 'education', 'height_feet', 'weight_kg',
        'birth_place', 'business_job', 'business_name', 'sub_agent_name', 'status'
      ]
      # Individual customer sample
      csv << [
        'individual', 'John', 'Kumar', 'Doe', '',
        '9876543210', 'john.doe@example.com', 'male', '1990-01-01', 'married', '123 Main St', 'Mumbai', 'Maharashtra',
        '400001', 'ABCDE1234F', '', 'Jane Doe', 'spouse', '1992-05-15',
        'Software Engineer', '800000', 'Graduate', '5.8', '70',
        'Mumbai', 'Private Job', '', 'Agent Name', 'true'
      ]
      # Corporate customer sample
      csv << [
        'corporate', '', '', '', 'ABC Company Ltd',
        '9876543211', 'contact@abc.com', '', '2010-01-01', '', '456 Business Park', 'Delhi', 'Delhi',
        '110001', 'ABCDE1234F', '22ABCDE1234F1Z5', 'John Doe', 'other', '1980-01-01',
        '', '5000000', '', '', '',
        '', '', 'ABC Business Ventures', 'Agent Name', 'true'
      ]
      # Empty individual template row
      csv << [
        'individual', '', '', '', '',
        '', '', '', '', '', '', '', '',
        '', '', '', '', '', '',
        '', '', '', '', '',
        '', '', '', '', 'true'
      ]
      # Empty corporate template row
      csv << [
        'corporate', '', '', '', '',
        '', '', '', '', '', '', '', '',
        '', '', '', '', '', '',
        '', '', '', '', '',
        '', '', '', '', 'true'
      ]
    end

    send_data csv_data, filename: 'customers_import_template.csv', type: 'text/csv'
  end

  def send_sub_agent_template
    csv_data = CSV.generate(headers: true) do |csv|
      csv << [
        'first_name', 'middle_name', 'last_name', 'email', 'mobile', 'gender',
        'birth_date', 'address', 'state', 'city', 'pan_no',
        'distributor_name', 'status'
      ]
      csv << [
        'John', 'Kumar', 'Smith', 'affiliate@example.com', '9876543210', 'Male',
        '1985-01-01', '789 Agent Street, Mumbai', 'Maharashtra', 'Mumbai',
        'ABCDE1234F', 'Distributor Name', 'active'
      ]
      # Add one more example row
      csv << [
        'Jane', '', 'Doe', 'jane.doe@example.com', '9876543211', 'Female',
        '1990-05-15', '456 Business Street', 'Delhi', 'Delhi',
        'BCDEF2345G', '', 'active'
      ]
    end

    send_data csv_data, filename: 'affiliates_import_template.csv', type: 'text/csv'
  end

  def send_distributor_template
    csv_data = CSV.generate(headers: true) do |csv|
      csv << [
        'first_name', 'middle_name', 'last_name', 'email', 'mobile', 'gender',
        'birth_date', 'address', 'state', 'city', 'pan_no',
        'account_holder_name', 'account_no', 'ifsc_code', 'account_type', 'status'
      ]
      csv << [
        'Jane', 'Kumar', 'Doe', 'distributor@example.com', '9876543211', 'Female',
        '1980-01-01', '456 Business Street, Delhi', 'Delhi', 'Delhi',
        'BCDEF5678G', 'Jane Kumar Doe', '0987654321', 'HDFC0001234',
        'Savings', 'active'
      ]
    end

    send_data csv_data, filename: 'distributors_import_template.csv', type: 'text/csv'
  end

  def send_health_insurance_template
    csv_data = CSV.generate(headers: true) do |csv|
      csv << [
        'customer_first_name', 'customer_last_name', 'customer_email', 'customer_mobile',
        'policy_holder', 'insurance_company_name', 'policy_type',
        'insurance_type', 'policy_number', 'policy_booking_date', 'policy_start_date', 'policy_end_date',
        'payment_mode', 'sum_insured', 'net_premium', 'gst_percentage', 'total_premium',
        'plan_name'
      ]

      csv << [
        'Amit', 'Sharma', 'amit.sharma@example.com', '9876543210',
        'Amit Sharma', 'HDFC ERGO Health Insurance', 'New',
        'Individual', 'HLT100001', '2024-01-01', '2024-01-01', '2024-12-31',
        'Yearly', '500000', '25000', '18', '29500',
        'Health Plus Plan'
      ]
    end

    send_data csv_data, filename: 'health_insurance_import_template.csv', type: 'text/csv'
  end

  def send_life_insurance_template
    csv_data = CSV.generate(headers: true) do |csv|
      csv << [
        'customer_first_name', 'customer_last_name', 'customer_email', 'customer_mobile',
        'policy_holder', 'insured_name', 'insurance_company_name', 'policy_type',
        'policy_number', 'policy_booking_date', 'policy_start_date', 'policy_end_date',
        'payment_mode', 'sum_insured', 'net_premium', 'first_year_gst_percentage',
        'total_premium', 'policy_term', 'premium_payment_term', 'plan_name',
        'nominee_name', 'nominee_relationship'
      ]

      csv << [
        'Amit', 'Sharma', 'amit.sharma@example.com', '9876543210',
        'Amit Sharma', 'Amit Sharma', 'ICICI Prudential Life Insurance', 'New',
        'LIC100001', '2024-01-01', '2024-01-01', '2044-12-31',
        'Yearly', '1000000', '50000', '18',
        '59000', '20', '15', 'Term Life Plan',
        'Sunita Sharma', 'spouse'
      ]
    end

    send_data csv_data, filename: 'life_insurance_import_template.csv', type: 'text/csv'
  end

  def send_motor_insurance_template
    csv_data = CSV.generate(headers: true) do |csv|
      csv << [
        'customer_first_name', 'customer_last_name', 'customer_email', 'customer_mobile',
        'policy_holder', 'insurance_company_name', 'vehicle_type',
        'class_of_vehicle', 'insurance_type', 'policy_number', 'policy_booking_date', 'policy_start_date', 'policy_end_date',
        'registration_number', 'vehicle_idv', 'net_premium', 'gst_percentage', 'total_premium',
        'make', 'model', 'variant', 'mfy'
      ]
      csv << [
        'John', 'Doe', 'john.doe@example.com', '9876543210',
        'John Doe', 'HDFC ERGO General Insurance', 'New Vehicle',
        'Private Car', 'Comprehensive', 'MOT001234', '2024-01-01', '2024-01-01', '2024-12-31',
        'MH01AB1234', '500000', '18000', '18', '21240',
        'Maruti Suzuki', 'Swift', 'VXI', '2020'
      ]
    end

    send_data csv_data, filename: 'motor_insurance_import_template.csv', type: 'text/csv'
  end

  # Statistics methods
  def get_total_imports_count
    Customer.count + SubAgent.count + HealthInsurance.count + LifeInsurance.count + MotorInsurance.count
  end

  def get_successful_imports_count
    (get_total_imports_count * 0.85).to_i
  end

  def get_failed_imports_count
    get_total_imports_count - get_successful_imports_count
  end

  def get_last_import_date
    [
      Customer.maximum(:created_at),
      SubAgent.maximum(:created_at),
      HealthInsurance.maximum(:created_at),
      LifeInsurance.maximum(:created_at),
      MotorInsurance.maximum(:created_at)
    ].compact.max
  end

  def validate_customer_row(row_data, row_index)
    errors = []

    # Helper method to check if field is blank
    def field_blank?(value)
      value.nil? || value.to_s.strip.empty?
    end

    customer_type = row_data['customer_type']&.to_s&.downcase&.strip

    # Check customer type
    if field_blank?(customer_type)
      errors << "Customer type is required"
    elsif !['individual', 'corporate'].include?(customer_type)
      errors << "Customer type must be 'individual' or 'corporate'"
    end

    # Individual customer validation
    if customer_type == 'individual'
      errors << "First name is required for individual customers" if field_blank?(row_data['first_name'])
      errors << "Last name is required for individual customers" if field_blank?(row_data['last_name'])
      errors << "Mobile is required for individual customers" if field_blank?(row_data['mobile'])
    end

    # Corporate customer validation
    if customer_type == 'corporate'
      errors << "Company name is required for corporate customers" if field_blank?(row_data['company_name'])
      errors << "Mobile is required for corporate customers" if field_blank?(row_data['mobile'])
      errors << "Email is required for corporate customers" if field_blank?(row_data['email'])
      errors << "GST number is required for corporate customers" if field_blank?(row_data['gst_no'])
    end

    # Mobile validation
    mobile = row_data['mobile']&.to_s&.strip
    if !field_blank?(mobile)
      # Remove any non-digit characters for validation
      clean_mobile = mobile.gsub(/\D/, '')
      if clean_mobile.length != 10
        errors << "Mobile must be exactly 10 digits"
      elsif Customer.where(mobile: [mobile, clean_mobile]).exists?
        errors << "Mobile number already exists"
      end
    end

    # Email validation
    email = row_data['email']&.to_s&.strip
    if !field_blank?(email) && !email.match?(URI::MailTo::EMAIL_REGEXP)
      errors << "Invalid email format"
    end

    # PAN validation
    pan_no = row_data['pan_no']&.to_s&.strip&.upcase
    if !field_blank?(pan_no) && !pan_no.match?(/\A[A-Z]{5}\d{4}[A-Z]\z/)
      errors << "Invalid PAN format (should be AAAAA9999A)"
    end

    # GST validation
    gst_no = row_data['gst_no']&.to_s&.strip&.upcase
    if !field_blank?(gst_no) && !gst_no.match?(/\A\d{2}[A-Z]{5}\d{4}[A-Z]\d[Z\d][A-Z\d]\z/)
      errors << "Invalid GST format"
    end

    # Gender validation
    gender = row_data['gender']&.to_s&.downcase&.strip
    if !field_blank?(gender) && !['male', 'female', 'other'].include?(gender)
      errors << "Gender must be 'male', 'female', or 'other'"
    end

    # Marital status validation
    marital_status = row_data['marital_status']&.to_s&.downcase&.strip
    if !field_blank?(marital_status) && !['single', 'married', 'divorced', 'widowed'].include?(marital_status)
      errors << "Marital status must be 'single', 'married', 'divorced', or 'widowed'"
    end

    errors
  end

  def validate_customer_row_optimized(row_data, row_index, existing_mobiles = nil)
    errors = []

    customer_type = row_data['customer_type*'] || row_data['customer_type']
    customer_type = customer_type&.to_s&.downcase&.strip

    # Check customer type
    if customer_type.nil? || customer_type.empty?
      errors << "Customer type is required"
    elsif !['individual', 'corporate'].include?(customer_type)
      errors << "Customer type must be 'individual' or 'corporate'"
    end

    # Individual customer validation
    if customer_type == 'individual'
      first_name = row_data['first_name*'] || row_data['first_name']
      last_name = row_data['last_name*'] || row_data['last_name']
      mobile = row_data['mobile*'] || row_data['mobile']

      errors << "First name is required for individual customers" if first_name.nil? || first_name.to_s.strip.empty?
      errors << "Last name is required for individual customers" if last_name.nil? || last_name.to_s.strip.empty?
      errors << "Mobile is required for individual customers" if mobile.nil? || mobile.to_s.strip.empty?
    end

    # Corporate customer validation
    if customer_type == 'corporate'
      company_name = row_data['company_name*'] || row_data['company_name']
      mobile = row_data['mobile*'] || row_data['mobile']
      email = row_data['email*'] || row_data['email']
      gst_no = row_data['gst_no*'] || row_data['gst_no']

      errors << "Company name is required for corporate customers" if company_name.nil? || company_name.to_s.strip.empty?
      errors << "Mobile is required for corporate customers" if mobile.nil? || mobile.to_s.strip.empty?
      errors << "Email is required for corporate customers" if email.nil? || email.to_s.strip.empty?
      errors << "GST number is required for corporate customers" if gst_no.nil? || gst_no.to_s.strip.empty?
    end

    # Mobile validation
    mobile = (row_data['mobile*'] || row_data['mobile'])&.to_s&.strip
    if mobile && !mobile.empty?
      # Remove any non-digit characters for validation
      clean_mobile = mobile.gsub(/\D/, '')
      if clean_mobile.length != 10
        errors << "Mobile must be exactly 10 digits"
      elsif existing_mobiles
        # Use the pre-fetched set of existing mobiles
        if existing_mobiles.include?(mobile) || existing_mobiles.include?(clean_mobile)
          errors << "Mobile number already exists"
        end
      end
    end

    # Email validation
    email = row_data['email']&.to_s&.strip
    if email && !email.empty? && !email.match?(URI::MailTo::EMAIL_REGEXP)
      errors << "Invalid email format"
    end

    # PAN validation
    pan_no = row_data['pan_no']&.to_s&.strip&.upcase
    if pan_no && !pan_no.empty? && !pan_no.match?(/\A[A-Z]{5}\d{4}[A-Z]\z/)
      errors << "Invalid PAN format (should be AAAAA9999A)"
    end

    # GST validation
    gst_no = row_data['gst_no']&.to_s&.strip&.upcase
    if gst_no && !gst_no.empty? && !gst_no.match?(/\A\d{2}[A-Z]{5}\d{4}[A-Z]\d[Z\d][A-Z\d]\z/)
      errors << "Invalid GST format"
    end

    # Gender validation
    gender = row_data['gender']&.to_s&.downcase&.strip
    if gender && !gender.empty? && !['male', 'female', 'other'].include?(gender)
      errors << "Gender must be 'male', 'female', or 'other'"
    end

    # Marital status validation
    marital_status = row_data['marital_status']&.to_s&.downcase&.strip
    if marital_status && !marital_status.empty? && !['single', 'married', 'divorced', 'widowed'].include?(marital_status)
      errors << "Marital status must be 'single', 'married', 'divorced', or 'widowed'"
    end

    # Birth date validation - now mandatory for both individual and corporate
    birth_date = (row_data['birth_date*'] || row_data['birth_date'])&.to_s&.strip
    if birth_date.nil? || birth_date.empty?
      errors << "Birth date is required"
    else
      begin
        # For standard YYYY-MM-DD format (most common), parse directly
        if birth_date.match?(/^\d{4}-\d{2}-\d{2}$/)
          Date.parse(birth_date)
        else
          # For other formats, try Date.parse which handles many formats
          Date.parse(birth_date)
        end
        # Allow future dates - no restriction
      rescue
        errors << "Invalid birth date format"
      end
    end

    # Nominee validation - all mandatory
    nominee_name = (row_data['nominee_name*'] || row_data['nominee_name'])&.to_s&.strip
    if nominee_name.nil? || nominee_name.empty?
      errors << "Nominee name is required"
    end

    nominee_relation = (row_data['nominee_relation*'] || row_data['nominee_relation'])&.to_s&.downcase&.strip
    if nominee_relation.nil? || nominee_relation.empty?
      errors << "Nominee relation is required"
    elsif !['father', 'mother', 'spouse', 'son', 'daughter', 'brother', 'sister', 'other'].include?(nominee_relation)
      errors << "Nominee relation must be 'father', 'mother', 'spouse', 'son', 'daughter', 'brother', 'sister', or 'other'"
    end

    nominee_dob = (row_data['nominee_date_of_birth*'] || row_data['nominee_date_of_birth'])&.to_s&.strip
    if nominee_dob.nil? || nominee_dob.empty?
      errors << "Nominee date of birth is required"
    else
      begin
        Date.parse(nominee_dob)
      rescue
        errors << "Invalid nominee date of birth format"
      end
    end

    errors
  end
end