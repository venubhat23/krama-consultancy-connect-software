# Simple test data for Health Insurance Module

puts "🏥 Creating simple test data for Health Insurance..."

# Create essential data only
puts "Creating brokers..."
Broker.find_or_create_by(name: "HDFC ERGO Broker") { |b| b.status = "active" }
Broker.find_or_create_by(name: "Star Health Broker") { |b| b.status = "active" }

puts "Creating agency codes..."
AgencyCode.find_or_create_by(code: "BA000424798") do |ac|
  ac.insurance_type = "Health"
  ac.company_name = "Star Health Allied Insurance Co Ltd"
  ac.agent_name = "Bharath D"
end

puts "Creating test customer..."
customer = Customer.find_or_create_by(email: "test@example.com") do |c|
  c.customer_type = "individual"
  c.first_name = "Test"
  c.last_name = "Customer"
  c.mobile = "9876543210"
  c.status = true
end

puts "Creating test sub agent..."
sub_agent = SubAgent.find_or_create_by(email: "agent@example.com") do |sa|
  sa.first_name = "Test"
  sa.last_name = "Agent"
  sa.mobile = "9876543211"
  sa.role_id = 1
  sa.status = "active"
  sa.gender = "Male"
end

puts "✅ Test data created successfully!"
puts "- Brokers: #{Broker.count}"
puts "- Agency Codes: #{AgencyCode.count}"
puts "- Customers: #{Customer.count}"
puts "- Sub Agents: #{SubAgent.count}"