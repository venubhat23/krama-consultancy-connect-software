# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create Admin User (primary)
all_sidebar = %w[dashboard analytics customers sub_agents distributors leads health_insurances life_insurances motor_insurances other_insurances system_settings banners roles users brokers agency_codes broker_codes commission_payouts distributor_payouts payouts invoices investors reports settings permissions user_roles management client_requests agency_brokers insurance_companies imports]
all_crud = all_sidebar.each_with_object({}) { |mod, h| h[mod] = { 'view' => 'on', 'create' => 'on', 'edit' => 'on', 'delete' => 'on' } }

super_admin_role = Role.find_or_create_by!(name: 'super_admin') do |r|
  r.description = 'Full system access with all privileges.'
  r.status = true
end

admin = User.find_or_initialize_by(email: "admin@drwise.com")
admin.assign_attributes(
  first_name: "Admin",
  last_name: "User",
  mobile: "9876543210",
  password: "admin@123",
  password_confirmation: "admin@123",
  user_type: "admin",
  role_id: super_admin_role.id,
  role_name: "super_admin",
  status: true,
  is_active: true,
  address: "123 Admin Street",
  city: "Bangalore",
  state: "Karnataka",
  sidebar_permissions: all_sidebar.to_json,
  crud_permissions: all_crud.to_json
)
admin.save!(validate: false)

puts "Created/Updated Admin User: #{admin.email}"

# Also keep the legacy admin user
User.find_or_create_by!(email: "admin@drwise.in") do |user|
  user.first_name = "Admin"
  user.last_name = "User"
  user.mobile = "9876543219"
  user.password = "admin123"
  user.password_confirmation = "admin123"
  user.user_type = "admin"
  user.role = "super_admin"
  user.status = true
  user.address = "123 Admin Street"
  user.city = "Bangalore"
  user.state = "Karnataka"
end

# Create some Insurance Companies
insurance_companies = [
  "HDFC Life Insurance",
  "ICICI Prudential",
  "LIC of India",
  "Bajaj Allianz",
  "TATA AIG"
]

insurance_companies.each do |name|
  InsuranceCompany.find_or_create_by!(name: name) do |company|
    company.status = true
  end
end

puts "Created #{insurance_companies.count} Insurance Companies"

# Create Agency/Brokers
agency_brokers = [
  { broker_name: "ABC Insurance Brokers", broker_code: "ABC001", agency_code: "AG001" },
  { broker_name: "XYZ Financial Services", broker_code: "XYZ002", agency_code: "AG002" },
  { broker_name: "PQR Insurance Agency", broker_code: "PQR003", agency_code: "AG003" }
]

agency_brokers.each do |broker_data|
  AgencyBroker.find_or_create_by!(broker_code: broker_data[:broker_code]) do |broker|
    broker.broker_name = broker_data[:broker_name]
    broker.agency_code = broker_data[:agency_code]
    broker.status = true
  end
end

puts "Created #{agency_brokers.count} Agency/Brokers"

# Create some Agents
agents_data = [
  { first_name: "Rajesh", last_name: "Kumar", email: "rajesh@drwise.in", mobile: "9876543211" },
  { first_name: "Priya", last_name: "Sharma", email: "priya@drwise.in", mobile: "9876543212" },
  { first_name: "Amit", last_name: "Patel", email: "amit@drwise.in", mobile: "9876543213" }
]

agents_data.each do |agent_data|
  User.find_or_create_by!(email: agent_data[:email]) do |user|
    user.first_name = agent_data[:first_name]
    user.last_name = agent_data[:last_name]
    user.mobile = agent_data[:mobile]
    user.password = "password"
    user.password_confirmation = "password"
    user.user_type = "agent"
    user.role = "agent_role"
    user.status = true
    user.address = "#{agent_data[:first_name]} Street"
    user.city = "Mumbai"
    user.state = "Maharashtra"
  end
end

puts "Created #{agents_data.count} Agents"

# Create some Customers
customers_data = [
  { first_name: "Ravi", last_name: "Agarwal", email: "ravi.agarwal@gmail.com", mobile: "8765432101", customer_type: "individual", city: "Delhi", state: "Delhi" },
  { first_name: "Sunita", last_name: "Mehta", email: "sunita.mehta@gmail.com", mobile: "8765432102", customer_type: "individual", city: "Mumbai", state: "Maharashtra" },
  { first_name: "", last_name: "", company_name: "Tech Solutions Pvt Ltd", email: "info@techsolutions.com", mobile: "8765432103", customer_type: "corporate", city: "Bangalore", state: "Karnataka" },
  { first_name: "Vikash", last_name: "Singh", email: "vikash.singh@gmail.com", mobile: "8765432104", customer_type: "individual", city: "Pune", state: "Maharashtra" },
  { first_name: "Neha", last_name: "Gupta", email: "neha.gupta@gmail.com", mobile: "8765432105", customer_type: "individual", city: "Chennai", state: "Tamil Nadu" }
]

customers_data.each do |customer_data|
  Customer.find_or_create_by!(mobile: customer_data[:mobile]) do |customer|
    customer.first_name = customer_data[:first_name]
    customer.last_name = customer_data[:last_name]
    customer.company_name = customer_data[:company_name]
    customer.email = customer_data[:email]
    customer.customer_type = customer_data[:customer_type]
    customer.address = "Sample Address"
    customer.city = customer_data[:city]
    customer.state = customer_data[:state]
    customer.birth_date = Date.current - rand(25..65).years if customer_data[:customer_type] == "individual"
    customer.status = true
    customer.added_by = "admin"
  end
end

puts "Created #{customers_data.count} Customers"

# Create some Leads
leads_data = [
  { name: "Deepak Kumar", contact_number: "7654321011", email: "deepak@gmail.com", product_interest: "Life Insurance", current_stage: "consultation" },
  { name: "Anita Devi", contact_number: "7654321012", email: "anita@gmail.com", product_interest: "Health Insurance", current_stage: "one_on_one" },
  { name: "Rohit Sharma", contact_number: "7654321013", email: "rohit@gmail.com", product_interest: "Motor Insurance", current_stage: "converted" },
  { name: "Tech Corp Ltd", contact_number: "7654321014", email: "contact@techcorp.com", product_interest: "Corporate Health Insurance", current_stage: "policy_created" },
  { name: "Kavya Nair", contact_number: "7654321015", email: "kavya@gmail.com", product_interest: "Travel Insurance", current_stage: "consultation" }
]

leads_data.each do |lead_data|
  Lead.find_or_create_by!(contact_number: lead_data[:contact_number]) do |lead|
    lead.name = lead_data[:name]
    lead.email = lead_data[:email]
    lead.product_interest = lead_data[:product_interest]
    lead.current_stage = lead_data[:current_stage]
    lead.referred_by = "Website"
    lead.created_date = Date.current - rand(1..30).days
    lead.note = "Sample lead from seeding"
  end
end

puts "Created #{leads_data.count} Leads"

puts "Seed data created successfully!"
puts "Admin Login: admin@drwise.in / password"
