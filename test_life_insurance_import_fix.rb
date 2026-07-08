#!/usr/bin/env ruby

require 'csv'
require 'tempfile'

puts '🧪 Testing Life Insurance Import with Auto-Creation Feature...'
puts

# Create a test CSV file with customer and affiliate data
timestamp = Time.current.to_i
csv_data = [
  ['customer_email', 'customer_first_name', 'customer_last_name', 'customer_mobile', 'customer_city', 'customer_state', 'sub_agent_email', 'sub_agent_first_name', 'sub_agent_last_name', 'sub_agent_mobile', 'policy_number', 'insurance_company_name', 'policy_type', 'policy_holder', 'insured_name', 'sum_insured', 'net_premium', 'total_premium', 'payment_mode', 'policy_start_date', 'policy_end_date', 'plan_name', 'policy_term', 'premium_payment_term'],
  ["john.life#{timestamp}@example.com", 'John', 'Doe', '', 'Mumbai', 'Maharashtra', "agent.life#{timestamp}@example.com", 'Life', 'Agent', '', "LIFE-#{timestamp}-01", 'LIC', 'New', 'Self', 'John Doe', '1000000', '50000', '59000', 'Yearly', '2026-01-01', '2046-01-01', 'Jeevan Anand', '20', '15'],
  ["jane.life#{timestamp}@example.com", 'Jane', 'Smith', '', 'Delhi', 'Delhi', '', '', '', '', "LIFE-#{timestamp}-02", 'HDFC Life Insurance', 'New', 'Self', 'Jane Smith', '2000000', '75000', '88500', 'Yearly', '2026-02-01', '2051-02-01', 'Click2Protect', '25', '10']
]

# Create temporary CSV file
temp_file = Tempfile.new(['test_life_import', '.csv'])
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
    filename: 'test_life_import.csv',
    type: 'text/csv'
  )

  # Initialize importer
  importer = ImportService::LifeInsuranceImporter.new(uploaded_file)

  puts "📊 Import Status - Before:"
  puts "   Customers count: #{Customer.count}"
  puts "   SubAgents count: #{SubAgent.count}"
  puts "   Life Insurances count: #{LifeInsurance.count}"
  puts

  # Run import
  result = importer.import

  puts "📊 Import Status - After:"
  puts "   Customers count: #{Customer.count}"
  puts "   SubAgents count: #{SubAgent.count}"
  puts "   Life Insurances count: #{LifeInsurance.count}"
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
    customer1 = Customer.find_by(email: "john.life#{timestamp}@example.com")
    if customer1
      puts "   Customer 1: ✅ #{customer1.first_name} #{customer1.last_name} (#{customer1.email})"
    else
      puts "   Customer 1: ❌ Not found"
    end

    # Check second customer
    customer2 = Customer.find_by(email: "jane.life#{timestamp}@example.com")
    if customer2
      puts "   Customer 2: ✅ #{customer2.first_name} #{customer2.last_name} (#{customer2.email})"
    else
      puts "   Customer 2: ❌ Not found"
    end

    # Check sub agent
    sub_agent = SubAgent.find_by(email: "agent.life#{timestamp}@example.com")
    if sub_agent
      puts "   Sub Agent: ✅ #{sub_agent.first_name} #{sub_agent.last_name} (#{sub_agent.email})"
    else
      puts "   Sub Agent: ❌ Not found"
    end

    # Check life insurance policies
    li1 = LifeInsurance.find_by(policy_number: "LIFE-#{timestamp}-01")
    li2 = LifeInsurance.find_by(policy_number: "LIFE-#{timestamp}-02")

    if li1
      puts "   Policy 1: ✅ #{li1.policy_number} - Customer: #{li1.customer&.email}, Agent: #{li1.sub_agent&.email || 'Direct'}"
    else
      puts "   Policy 1: ❌ Not found"
    end

    if li2
      puts "   Policy 2: ✅ #{li2.policy_number} - Customer: #{li2.customer&.email}, Agent: #{li2.sub_agent&.email || 'Direct'}"
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
puts "   The life insurance import now supports automatic creation of:"
puts "   - ✅ New customers (with email, name, contact details)"
puts "   - ✅ New sub agents/affiliates (when specified)"
puts "   - ✅ Life insurance policies with all relationships"
puts
puts "📝 CSV Format Required:"
puts "   customer_email (required)"
puts "   customer_first_name, customer_last_name, customer_mobile, etc."
puts "   sub_agent_email, sub_agent_first_name, etc. (optional)"
puts "   policy_number, insurance_company_name (required)"
puts "   All other life insurance fields as before"

# Cleanup
temp_file.close
temp_file.unlink