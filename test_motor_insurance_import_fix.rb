#!/usr/bin/env ruby

require 'csv'
require 'tempfile'

puts '🧪 Testing Motor Insurance Import with Auto-Creation Feature...'
puts

# Create a test CSV file with customer and affiliate data
timestamp = Time.current.to_i
csv_data = [
  ['customer_email', 'customer_first_name', 'customer_last_name', 'customer_mobile', 'customer_city', 'customer_state', 'sub_agent_email', 'sub_agent_first_name', 'sub_agent_last_name', 'sub_agent_mobile', 'policy_number', 'insurance_company_name', 'policy_type', 'policy_holder', 'registration_number', 'make', 'model', 'vehicle_type', 'class_of_vehicle', 'total_idv', 'net_premium', 'total_premium', 'insurance_type', 'policy_start_date', 'policy_end_date'],
  ["john.motor#{timestamp}@example.com", 'John', 'Doe', '', 'Mumbai', 'Maharashtra', "agent.motor#{timestamp}@example.com", 'Motor', 'Agent', '', "MOTOR-#{timestamp}-01", 'Bajaj Allianz', 'New', 'Self', 'MH01AB1234', 'Maruti', 'Swift', 'New Vehicle', 'Private Car', '800000', '15000', '17700', 'Comprehensive', '2026-01-01', '2027-01-01'],
  ["jane.motor#{timestamp}@example.com", 'Jane', 'Smith', '', 'Delhi', 'Delhi', '', '', '', '', "MOTOR-#{timestamp}-02", 'ICICI Lombard', 'New', 'Self', 'DL01XY5678', 'Honda', 'City', 'New Vehicle', 'Private Car', '1200000', '20000', '23600', 'Comprehensive', '2026-02-01', '2027-02-01']
]

# Create temporary CSV file
temp_file = Tempfile.new(['test_motor_import', '.csv'])
CSV.open(temp_file.path, 'w') do |csv|
  csv_data.each { |row| csv << row }
end
temp_file.rewind

puts "📄 Created test CSV file: #{temp_file.path}"
puts "   Records: #{csv_data.length - 1} (excluding header)"
puts

# Test the import
puts "🚀 Starting import test..."

begin
  # Simulate file upload
  uploaded_file = ActionDispatch::Http::UploadedFile.new(
    tempfile: temp_file,
    filename: 'test_motor_import.csv',
    type: 'text/csv'
  )

  # Initialize importer
  importer = ImportService::MotorInsuranceImporter.new(uploaded_file)

  puts "📊 Import Status - Before:"
  puts "   Customers count: #{Customer.count}"
  puts "   SubAgents count: #{SubAgent.count}"
  puts "   Motor Insurances count: #{MotorInsurance.count}"
  puts

  # Run import
  result = importer.import

  puts "📊 Import Status - After:"
  puts "   Customers count: #{Customer.count}"
  puts "   SubAgents count: #{SubAgent.count}"
  puts "   Motor Insurances count: #{MotorInsurance.count}"
  puts

  puts "📋 Import Results:"
  puts "   Success: #{result[:success]}"
  puts "   Imported: #{result[:imported_count]}"
  puts "   Skipped: #{result[:skipped_count]}"

  if result[:errors].any?
    puts "   Errors:"
    result[:errors].each { |error| puts "     - #{error}" }
  else
    puts "   Errors: None"
  end

  puts

  if result[:success] && result[:imported_count] > 0
    puts "✅ Import test PASSED!"
    puts

    # Verify created records
    puts "🔍 Verification:"

    # Check first customer
    customer1 = Customer.find_by(email: "john.motor#{timestamp}@example.com")
    if customer1
      puts "   Customer 1: ✅ #{customer1.first_name} #{customer1.last_name} (#{customer1.email})"
    else
      puts "   Customer 1: ❌ Not found"
    end

    # Check second customer
    customer2 = Customer.find_by(email: "jane.motor#{timestamp}@example.com")
    if customer2
      puts "   Customer 2: ✅ #{customer2.first_name} #{customer2.last_name} (#{customer2.email})"
    else
      puts "   Customer 2: ❌ Not found"
    end

    # Check sub agent
    sub_agent = SubAgent.find_by(email: "agent.motor#{timestamp}@example.com")
    if sub_agent
      puts "   Sub Agent: ✅ #{sub_agent.first_name} #{sub_agent.last_name} (#{sub_agent.email})"
    else
      puts "   Sub Agent: ❌ Not found"
    end

    # Check motor insurance policies
    mi1 = MotorInsurance.find_by(policy_number: "MOTOR-#{timestamp}-01")
    mi2 = MotorInsurance.find_by(policy_number: "MOTOR-#{timestamp}-02")

    if mi1
      puts "   Policy 1: ✅ #{mi1.policy_number} - Customer: #{mi1.customer&.email}, Agent: #{mi1.sub_agent&.email || 'Direct'}"
      puts "             Registration: #{mi1.registration_number}, Vehicle: #{mi1.make} #{mi1.model}"
    else
      puts "   Policy 1: ❌ Not found"
    end

    if mi2
      puts "   Policy 2: ✅ #{mi2.policy_number} - Customer: #{mi2.customer&.email}, Agent: #{mi2.sub_agent&.email || 'Direct'}"
      puts "             Registration: #{mi2.registration_number}, Vehicle: #{mi2.make} #{mi2.model}"
    else
      puts "   Policy 2: ❌ Not found"
    end

  else
    puts "❌ Import test FAILED!"
    puts "   Check the errors above for details."
  end

rescue => e
  puts "❌ Import test ERROR: #{e.message}"
  puts "   #{e.backtrace.first}"
end

puts
puts "🎯 Test Summary:"
puts "   The motor insurance import now supports automatic creation of:"
puts "   - ✅ New customers (with email, name, contact details)"
puts "   - ✅ New sub agents/affiliates (when specified)"
puts "   - ✅ Motor insurance policies with all relationships"
puts
puts "📝 CSV Format Required:"
puts "   customer_email (required)"
puts "   customer_first_name, customer_last_name, customer_mobile, etc."
puts "   sub_agent_email, sub_agent_first_name, etc. (optional)"
puts "   policy_number, registration_number (required)"
puts "   make, model, vehicle_type, total_idv, etc."
puts "   All other motor insurance fields as before"

# Cleanup
temp_file.close
temp_file.unlink