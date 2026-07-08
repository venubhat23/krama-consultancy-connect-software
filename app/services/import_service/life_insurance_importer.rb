require 'csv'
require 'roo'

module ImportService
  class LifeInsuranceImporter
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
      required_headers = %w[customer_email policy_number insurance_company_name]
      missing_headers = required_headers - header.map(&:to_s).map(&:downcase)

      if missing_headers.any?
        raise "Missing required headers: #{missing_headers.join(', ')}"
      end
    end

    def process_row(row, row_number)
      # Clean and normalize data
      insurance_data = normalize_insurance_data(row)

      # Validate row data
      if !valid_row?(insurance_data, row_number)
        @skipped_count += 1
        return
      end

      # Find or create customer
      customer = find_or_create_customer(insurance_data, row_number)
      return unless customer

      # Find or create sub agent (optional)
      sub_agent = find_or_create_sub_agent(insurance_data, row_number)

      # Check for duplicates
      if duplicate_policy?(insurance_data)
        @errors << "Row #{row_number}: Policy with number '#{insurance_data[:policy_number]}' already exists"
        @skipped_count += 1
        return
      end

      # Prepare life insurance data
      life_insurance_data = prepare_life_insurance_data(insurance_data, customer, sub_agent)

      life_insurance = LifeInsurance.new(life_insurance_data)

      if life_insurance.save
        @imported_count += 1
      else
        @errors << "Row #{row_number}: #{life_insurance.errors.full_messages.join(', ')}"
        @skipped_count += 1
      end

    rescue => e
      @errors << "Row #{row_number}: #{e.message}"
      @skipped_count += 1
    end

    def normalize_insurance_data(row)
      {
        # Customer fields
        customer_email: row['customer_email']&.to_s&.downcase&.strip,
        customer_first_name: row['customer_first_name']&.to_s&.strip,
        customer_last_name: row['customer_last_name']&.to_s&.strip,
        customer_mobile: row['customer_mobile']&.to_s&.strip,
        customer_address: row['customer_address']&.to_s&.strip,
        customer_city: row['customer_city']&.to_s&.strip,
        customer_state: row['customer_state']&.to_s&.strip,
        customer_pincode: row['customer_pincode']&.to_s&.strip,
        customer_pan_no: row['customer_pan_no']&.to_s&.strip,
        customer_type: row['customer_type']&.to_s&.downcase&.strip || 'individual',
        customer_age: parse_number(row['customer_age']),

        # Sub Agent fields
        sub_agent_email: row['sub_agent_email']&.to_s&.downcase&.strip,
        sub_agent_first_name: row['sub_agent_first_name']&.to_s&.strip,
        sub_agent_last_name: row['sub_agent_last_name']&.to_s&.strip,
        sub_agent_mobile: row['sub_agent_mobile']&.to_s&.strip,

        # Life Insurance fields
        policy_holder: row['policy_holder']&.to_s&.strip,
        insured_name: row['insured_name']&.to_s&.strip,
        insurance_company_name: row['insurance_company_name']&.to_s&.strip,
        policy_number: row['policy_number']&.to_s&.strip,
        policy_booking_date: parse_date(row['policy_booking_date']) || Date.current,
        policy_start_date: parse_date(row['policy_start_date']),
        policy_end_date: parse_date(row['policy_end_date']),
        payment_mode: row['payment_mode']&.to_s&.strip,
        sum_insured: parse_number(row['sum_insured']),
        net_premium: parse_number(row['net_premium']),
        first_year_gst_percentage: parse_number(row['first_year_gst_percentage']),
        total_premium: parse_number(row['total_premium']),
        plan_name: row['plan_name']&.to_s&.strip,
        policy_term: parse_number(row['policy_term']),
        premium_payment_term: parse_number(row['premium_payment_term']),
        policy_type: row['policy_type']&.to_s&.strip || 'New',
        nominee_name: row['nominee_name']&.to_s&.strip,
        nominee_relationship: row['nominee_relationship']&.to_s&.strip,
        distributor_id: find_or_create_default_distributor&.id,
        is_admin_added: true,
        is_agent_added: false,
        is_customer_added: false,
        active: true
      }.compact
    end

    def valid_row?(insurance_data, row_number)
      # Check required fields
      if insurance_data[:customer_email].blank?
        @errors << "Row #{row_number}: customer_email is required"
        return false
      end

      if insurance_data[:policy_number].blank?
        @errors << "Row #{row_number}: policy_number is required"
        return false
      end

      if insurance_data[:insurance_company_name].blank?
        @errors << "Row #{row_number}: insurance_company_name is required"
        return false
      end

      # Check email format
      if !insurance_data[:customer_email].match?(URI::MailTo::EMAIL_REGEXP)
        @errors << "Row #{row_number}: Invalid email format"
        return false
      end

      true
    end

    def find_or_create_customer(insurance_data, row_number)
      email = insurance_data[:customer_email]
      customer = Customer.find_by(email: email)

      unless customer
        # Create new customer
        customer_attrs = {
          email: email,
          first_name: insurance_data[:customer_first_name].presence || email.split('@').first.capitalize,
          last_name: insurance_data[:customer_last_name].presence || '-',
          mobile: insurance_data[:customer_mobile].present? ? insurance_data[:customer_mobile] : generate_unique_mobile,
          address: insurance_data[:customer_address],
          city: insurance_data[:customer_city],
          state: insurance_data[:customer_state],
          pincode: insurance_data[:customer_pincode],
          pan_no: insurance_data[:customer_pan_no],
          customer_type: insurance_data[:customer_type] || 'individual',
          age: insurance_data[:customer_age],
          birth_date: Date.current - 30.years,  # Default age 30
          nominee_name: 'TBD',
          nominee_relation: 'spouse',
          nominee_date_of_birth: Date.current - 25.years,
          added_by: 'admin'
        }
        customer_attrs.compact!

        customer = Customer.new(customer_attrs)

        if customer.save
          Rails.logger.info "Created new customer: #{customer.email}"
        else
          @errors << "Row #{row_number}: Failed to create customer - #{customer.errors.full_messages.join(', ')}"
          @skipped_count += 1
          return nil
        end
      end

      customer
    end

    def find_or_create_sub_agent(insurance_data, row_number)
      return nil if insurance_data[:sub_agent_email].blank?

      email = insurance_data[:sub_agent_email]
      sub_agent = SubAgent.find_by(email: email)

      unless sub_agent
        # Create new sub agent
        sub_agent_attrs = {
          email: email,
          first_name: insurance_data[:sub_agent_first_name].presence || email.split('@').first.capitalize,
          last_name: insurance_data[:sub_agent_last_name].presence || '-',
          mobile: insurance_data[:sub_agent_mobile].present? ? insurance_data[:sub_agent_mobile] : generate_unique_mobile,
          original_password: SecureRandom.hex(8),
          role_id: 1  # sub_agent role
        }
        sub_agent_attrs.compact!

        sub_agent = SubAgent.new(sub_agent_attrs)

        if sub_agent.save
          Rails.logger.info "Created new sub agent: #{sub_agent.email}"
        else
          @errors << "Row #{row_number}: Failed to create sub agent - #{sub_agent.errors.full_messages.join(', ')}"
          return nil
        end
      end

      sub_agent
    end

    def prepare_life_insurance_data(insurance_data, customer, sub_agent)
      # Remove customer and sub_agent specific fields
      cleaned_data = insurance_data.dup
      cleaned_data.delete(:customer_email)
      cleaned_data.delete(:customer_first_name)
      cleaned_data.delete(:customer_last_name)
      cleaned_data.delete(:customer_mobile)
      cleaned_data.delete(:customer_address)
      cleaned_data.delete(:customer_city)
      cleaned_data.delete(:customer_state)
      cleaned_data.delete(:customer_pincode)
      cleaned_data.delete(:customer_pan_no)
      cleaned_data.delete(:customer_type)
      cleaned_data.delete(:customer_age)
      cleaned_data.delete(:sub_agent_email)
      cleaned_data.delete(:sub_agent_first_name)
      cleaned_data.delete(:sub_agent_last_name)
      cleaned_data.delete(:sub_agent_mobile)

      # Set required associations
      cleaned_data[:customer_id] = customer.id
      cleaned_data[:sub_agent_id] = sub_agent&.id

      cleaned_data
    end

    def duplicate_policy?(insurance_data)
      LifeInsurance.exists?(policy_number: insurance_data[:policy_number])
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

    def generate_unique_mobile
      loop do
        mobile = "9#{rand(100000000..999999999)}"
        return mobile unless Customer.exists?(mobile: mobile) || SubAgent.exists?(mobile: mobile) || Ambassador.exists?(mobile: mobile) rescue return mobile
      end
    end

    def find_or_create_default_distributor
      return nil unless defined?(Distributor)

      # Try to find an existing distributor
      distributor = Distributor.first
      return distributor if distributor

      # Create a default distributor if none exists
      begin
        Distributor.create!(
          company_name: 'Default Distributor',
          first_name: 'Admin',
          last_name: 'User',
          email: "admin@insurebook.com",
          mobile: generate_unique_mobile,
          original_password: SecureRandom.hex(8)
        )
      rescue => e
        Rails.logger.warn "Failed to create default distributor: #{e.message}"
        nil
      end
    end
  end
end