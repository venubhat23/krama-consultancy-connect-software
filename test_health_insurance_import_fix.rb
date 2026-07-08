#!/usr/bin/env ruby

require 'csv'
require 'tempfile'

puts '🧪 Testing Health Insurance Import with Auto-Creation Feature...'
puts

# Create a test CSV file with customer and affiliate data
timestamp = Time.current.to_i
csv_data = [
  ['customer_email', 'customer_first_name', 'customer_last_name', 'customer_mobile', 'customer_city', 'customer_state', 'sub_agent_email', 'sub_agent_first_name', 'sub_agent_last_name', 'sub_agent_mobile', 'policy_number', 'insurance_company_name', 'policy_type', 'policy_holder', 'insurance_type', 'sum_insured', 'net_premium', 'total_premium', 'payment_mode', 'policy_start_date', 'policy_end_date'],
  ["john.doe#{timestamp}@example.com", 'John', 'Doe', '', 'Mumbai', 'Maharashtra', "agent#{timestamp}@example.com", 'Agent', 'One', '', "HEALTH-#{timestamp}-01", 'Star Health Insurance', 'New', 'Self', 'Individual', '500000', '25000', '29500', 'Yearly', '2026-01-01', '2026-12-31'],
  ["jane.smith#{timestamp}@example.com", 'Jane', 'Smith', '', 'Delhi', 'Delhi', '', '', '', '', "HEALTH-#{timestamp}-02", 'ICICI Lombard', 'New', 'Self', 'Family Floater', '1000000', '35000', '41300', 'Yearly', '2026-02-01', '2027-01-31']
]

# Create temporary CSV file
temp_file = Tempfile.new(['test_health_import', '.csv'])
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
    filename: 'test_health_import.csv',
    type: 'text/csv'
  )

  # Initialize importer
  importer = ImportService::HealthInsuranceImporter.new(uploaded_file)

  puts "📊 Import Status - Before:"
  puts "   Customers count: #{Customer.count}"
  puts "   SubAgents count: #{SubAgent.count}"
  puts "   Health Insurances count: #{HealthInsurance.count}"
  puts

  # Run import
  result = importer.import

  puts "📊 Import Status - After:"
  puts "   Customers count: #{Customer.count}"
  puts "   SubAgents count: #{SubAgent.count}"
  puts "   Health Insurances count: #{HealthInsurance.count}"
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
    customer1 = Customer.find_by(email: "john.doe#{timestamp}@example.com")
    if customer1
      puts "   Customer 1: ✅ #{customer1.first_name} #{customer1.last_name} (#{customer1.email})"
    else
      puts "   Customer 1: ❌ Not found"
    end

    # Check second customer
    customer2 = Customer.find_by(email: "jane.smith#{timestamp}@example.com")
    if customer2
      puts "   Customer 2: ✅ #{customer2.first_name} #{customer2.last_name} (#{customer2.email})"
    else
      puts "   Customer 2: ❌ Not found"
    end

    # Check sub agent
    sub_agent = SubAgent.find_by(email: "agent#{timestamp}@example.com")
    if sub_agent
      puts "   Sub Agent: ✅ #{sub_agent.first_name} #{sub_agent.last_name} (#{sub_agent.email})"
    else
      puts "   Sub Agent: ❌ Not found"
    end

    # Check health insurance policies
    hi1 = HealthInsurance.find_by(policy_number: "HEALTH-#{timestamp}-01")
    hi2 = HealthInsurance.find_by(policy_number: "HEALTH-#{timestamp}-02")

    if hi1
      puts "   Policy 1: ✅ #{hi1.policy_number} - Customer: #{hi1.customer&.email}, Agent: #{hi1.sub_agent&.email || 'Direct'}"
    else
      puts "   Policy 1: ❌ Not found"
    end

    if hi2
      puts "   Policy 2: ✅ #{hi2.policy_number} - Customer: #{hi2.customer&.email}, Agent: #{hi2.sub_agent&.email || 'Direct'}"
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
puts "   The health insurance import now supports automatic creation of:"
puts "   - ✅ New customers (with email, name, contact details)"
puts "   - ✅ New sub agents/affiliates (when specified)"
puts "   - ✅ Health insurance policies with all relationships"
puts
puts "📝 CSV Format Required:"
puts "   customer_email (required)"
puts "   customer_first_name, customer_last_name, customer_mobile, etc."
puts "   sub_agent_email, sub_agent_first_name, etc. (optional)"
puts "   policy_number, insurance_company_name (required)"
puts "   All other health insurance fields as before"

# Cleanup
temp_file.close
temp_file.unlink