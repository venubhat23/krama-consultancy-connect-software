#!/usr/bin/env ruby

# Mock Data Generation Script for InsureBook Admin
# This script creates comprehensive test data for all modules

puts "🚀 Starting InsureBook Mock Data Generation..."
puts "=" * 60

# Clear existing test data if needed
def clear_test_data
  puts "🧹 Clearing existing test data..."
  # Be careful - this will delete data!
  # Uncomment if you want to reset data
  # HealthInsurance.destroy_all
  # LifeInsurance.destroy_all
  # Customer.where("email LIKE '%test%' OR email LIKE '%mock%'").destroy_all
  # User.where("email LIKE '%test%' OR email LIKE '%mock%'").destroy_all
  # SubAgent.where("email LIKE '%test%' OR email LIKE '%mock%'").destroy_all
end

# 1. Create Insurance Companies Data
def create_insurance_companies
  puts "\n🏢 Creating Insurance Companies..."

  companies = [
    "LIC of India",
    "SBI Life Insurance",
    "HDFC Life Insurance",
    "ICICI Prudential Life Insurance",
    "Bajaj Allianz Life Insurance",
    "Star Health Insurance",
    "HDFC ERGO Health Insurance",
    "Care Health Insurance",
    "Niva Bupa Health Insurance",
    "New India Assurance",
    "Oriental Insurance",
    "United India Insurance"
  ]

  companies.each do |company|
    # Store in a configuration or create a simple reference
    puts "  ✓ #{company}"
  end
end

# 2. Create Brokers
def create_brokers
  puts "\n🤝 Creating Brokers..."

  brokers_data = [
    { name: "Star Health Insurance Broker", status: "active" },
    { name: "HDFC ERGO Insurance Broker", status: "active" },
    { name: "Care Health Insurance Broker", status: "active" },
    { name: "ICICI Prudential Broker", status: "active" },
    { name: "SBI Life Insurance Broker", status: "active" }
  ]

  brokers_data.each do |broker_data|
    broker = Broker.find_or_create_by(name: broker_data[:name]) do |b|
      b.status = broker_data[:status]
    end
    puts "  ✓ Created broker: #{broker.name}"
  end
end

# 3. Create Agency Codes
def create_agency_codes
  puts "\n🏷️ Creating Agency Codes..."

  agency_codes_data = [
    {
      code: "BA000424798",
      insurance_type: "Health",
      company_name: "Star Health Allied Insurance Co Ltd",
      agent_name: "Bharath D"
    },
    {
      code: "HL001234567",
      insurance_type: "Health",
      company_name: "HDFC ERGO Health Insurance",
      agent_name: "Rajesh Kumar"
    },
    {
      code: "LI009876543",
      insurance_type: "Life",
      company_name: "ICICI Prudential Life Insurance",
      agent_name: "Priya Sharma"
    },
    {
      code: "SB012345678",
      insurance_type: "Life",
      company_name: "SBI Life Insurance",
      agent_name: "Amit Singh"
    },
    {
      code: "CA987654321",
      insurance_type: "Health",
      company_name: "Care Health Insurance",
      agent_name: "Sneha Patel"
    }
  ]

  agency_codes_data.each do |ac_data|
    agency_code = AgencyCode.find_or_create_by(code: ac_data[:code]) do |ac|
      ac.insurance_type = ac_data[:insurance_type]
      ac.company_name = ac_data[:company_name]
      ac.agent_name = ac_data[:agent_name]
    end
    puts "  ✓ Created agency code: #{agency_code.code} (#{agency_code.company_name})"
  end
end

# 4. Create Admin Users and Agents
def create_users_and_agents
  puts "\n👤 Creating Users and Agents..."

  # Create Admin User
  admin = User.find_or_create_by(email: "admin@insurebook.com") do |u|
    u.first_name = "Super"
    u.last_name = "Admin"
    u.mobile = "9876543200"
    u.user_type = "admin"
    u.role = "super_admin"
    u.status = true
    u.password = "password123"
    u.password_confirmation = "password123"
  end
  puts "  ✓ Created admin: #{admin.email}"

  # Create Agent Users
  agents_data = [
    {
      email: "agent1@insurebook.com",
      first_name: "Rajesh",
      last_name: "Kumar",
      mobile: "9876543201",
      user_type: "agent",
      role: "agent_role"
    },
    {
      email: "agent2@insurebook.com",
      first_name: "Priya",
      last_name: "Sharma",
      mobile: "9876543202",
      user_type: "agent",
      role: "agent_role"
    },
    {
      email: "manager@insurebook.com",
      first_name: "Amit",
      last_name: "Singh",
      mobile: "9876543203",
      user_type: "agent",
      role: "manager"
    }
  ]

  agents_data.each do |agent_data|
    agent = User.find_or_create_by(email: agent_data[:email]) do |u|
      u.first_name = agent_data[:first_name]
      u.last_name = agent_data[:last_name]
      u.mobile = agent_data[:mobile]
      u.user_type = agent_data[:user_type]
      u.role = agent_data[:role]
      u.status = true
      u.password = "password123"
      u.password_confirmation = "password123"
    end
    puts "  ✓ Created agent: #{agent.email} (#{agent.full_name})"
  end
end

# 5. Create Sub Agents
def create_sub_agents
  puts "\n👥 Creating Sub Agents..."

  sub_agents_data = [
    {
      email: "subagent1@insurebook.com",
      first_name: "Sneha",
      last_name: "Patel",
      mobile: "9876543210",
      role_id: 1,
      gender: "Female"
    },
    {
      email: "subagent2@insurebook.com",
      first_name: "Vikash",
      last_name: "Gupta",
      mobile: "9876543211",
      role_id: 2,
      gender: "Male"
    },
    {
      email: "subagent3@insurebook.com",
      first_name: "Kavya",
      last_name: "Reddy",
      mobile: "9876543212",
      role_id: 1,
      gender: "Female"
    }
  ]

  sub_agents_data.each do |sa_data|
    sub_agent = SubAgent.find_or_create_by(email: sa_data[:email]) do |sa|
      sa.first_name = sa_data[:first_name]
      sa.last_name = sa_data[:last_name]
      sa.mobile = sa_data[:mobile]
      sa.role_id = sa_data[:role_id]
      sa.status = "active"
      sa.gender = sa_data[:gender]
    end
    puts "  ✓ Created sub-agent: #{sub_agent.email} (#{sub_agent.display_name})"
  end
end

# 6. Create Customers
def create_customers
  puts "\n👨‍👩‍👧‍👦 Creating Customers..."

  # Individual Customers
  individual_customers = [
    {
      email: "john.doe@test.com",
      first_name: "John",
      last_name: "Doe",
      mobile: "9988776651",
      gender: "male",
      birth_date: 35.years.ago,
      city: "Mumbai",
      state: "Maharashtra",
      address: "123 Marine Drive, Mumbai",
      pincode: "400001",
      occupation: "Software Engineer",
      annual_income: 1200000,
      marital_status: "married"
    },
    {
      email: "priya.sharma@test.com",
      first_name: "Priya",
      last_name: "Sharma",
      mobile: "9988776652",
      gender: "female",
      birth_date: 28.years.ago,
      city: "Delhi",
      state: "Delhi",
      address: "45 CP, New Delhi",
      pincode: "110001",
      occupation: "Doctor",
      annual_income: 1500000,
      marital_status: "single"
    },
    {
      email: "rajesh.kumar@test.com",
      first_name: "Rajesh",
      last_name: "Kumar",
      mobile: "9988776653",
      gender: "male",
      birth_date: 42.years.ago,
      city: "Bangalore",
      state: "Karnataka",
      address: "78 MG Road, Bangalore",
      pincode: "560001",
      occupation: "Business Owner",
      annual_income: 2000000,
      marital_status: "married"
    },
    {
      email: "sneha.patel@test.com",
      first_name: "Sneha",
      last_name: "Patel",
      mobile: "9988776654",
      gender: "female",
      birth_date: 31.years.ago,
      city: "Pune",
      state: "Maharashtra",
      address: "12 FC Road, Pune",
      pincode: "411001",
      occupation: "Teacher",
      annual_income: 800000,
      marital_status: "married"
    },
    {
      email: "vikash.gupta@test.com",
      first_name: "Vikash",
      last_name: "Gupta",
      mobile: "9988776655",
      gender: "male",
      birth_date: 25.years.ago,
      city: "Chennai",
      state: "Tamil Nadu",
      address: "34 Anna Salai, Chennai",
      pincode: "600001",
      occupation: "Marketing Manager",
      annual_income: 1000000,
      marital_status: "single"
    }
  ]

  individual_customers.each do |customer_data|
    customer = Customer.find_or_create_by(email: customer_data[:email]) do |c|
      c.customer_type = "individual"
      c.first_name = customer_data[:first_name]
      c.last_name = customer_data[:last_name]
      c.mobile = customer_data[:mobile]
      c.gender = customer_data[:gender]
      c.birth_date = customer_data[:birth_date]
      c.city = customer_data[:city]
      c.state = customer_data[:state]
      c.address = customer_data[:address]
      c.pincode = customer_data[:pincode]
      c.occupation = customer_data[:occupation]
      c.annual_income = customer_data[:annual_income]
      c.marital_status = customer_data[:marital_status]
      c.status = true
      c.added_by = 'mock_data_script'
    end
    puts "  ✓ Created customer: #{customer.email} (#{customer.display_name})"
  end

  # Corporate Customers
  corporate_customers = [
    {
      email: "hr@techcorp.com",
      company_name: "Tech Corp Solutions Pvt Ltd",
      mobile: "9988776660",
      city: "Mumbai",
      state: "Maharashtra",
      address: "Tower A, BKC, Mumbai",
      pincode: "400051",
      gst_no: "27ABCDE1234F1Z5"
    },
    {
      email: "admin@healthplus.com",
      company_name: "HealthPlus Medical Center",
      mobile: "9988776661",
      city: "Delhi",
      state: "Delhi",
      address: "Medical Complex, CP, Delhi",
      pincode: "110001",
      gst_no: "07FGHIJ5678K2Z8"
    }
  ]

  corporate_customers.each do |corp_data|
    corporate = Customer.find_or_create_by(email: corp_data[:email]) do |c|
      c.customer_type = "corporate"
      c.company_name = corp_data[:company_name]
      c.mobile = corp_data[:mobile]
      c.city = corp_data[:city]
      c.state = corp_data[:state]
      c.address = corp_data[:address]
      c.pincode = corp_data[:pincode]
      c.gst_no = corp_data[:gst_no]
      c.status = true
      c.added_by = 'mock_data_script'
    end
    puts "  ✓ Created corporate customer: #{corporate.email} (#{corporate.display_name})"
  end
end

# 7. Create Family Members for Individual Customers
def create_family_members
  puts "\n👨‍👩‍👧‍👦 Creating Family Members..."

  # Get some customers to add family members to
  john = Customer.find_by(email: "john.doe@test.com")
  rajesh = Customer.find_by(email: "rajesh.kumar@test.com")
  sneha = Customer.find_by(email: "sneha.patel@test.com")

  if john
    # John's family
    john.family_members.find_or_create_by(first_name: "Jane", last_name: "Doe") do |fm|
      fm.relationship = "spouse"
      fm.gender = "female"
      fm.birth_date = 33.years.ago
      fm.mobile = "9988776656"
    end

    john.family_members.find_or_create_by(first_name: "Johnny", last_name: "Doe") do |fm|
      fm.relationship = "son"
      fm.gender = "male"
      fm.birth_date = 8.years.ago
    end
    puts "  ✓ Added family members for John Doe"
  end

  if rajesh
    # Rajesh's family
    rajesh.family_members.find_or_create_by(first_name: "Sunita", last_name: "Kumar") do |fm|
      fm.relationship = "spouse"
      fm.gender = "female"
      fm.birth_date = 38.years.ago
      fm.mobile = "9988776657"
    end

    rajesh.family_members.find_or_create_by(first_name: "Ravi", last_name: "Kumar") do |fm|
      fm.relationship = "son"
      fm.gender = "male"
      fm.birth_date = 12.years.ago
    end

    rajesh.family_members.find_or_create_by(first_name: "Kavya", last_name: "Kumar") do |fm|
      fm.relationship = "daughter"
      fm.gender = "female"
      fm.birth_date = 10.years.ago
    end
    puts "  ✓ Added family members for Rajesh Kumar"
  end

  if sneha
    # Sneha's family
    sneha.family_members.find_or_create_by(first_name: "Rohan", last_name: "Patel") do |fm|
      fm.relationship = "spouse"
      fm.gender = "male"
      fm.birth_date = 34.years.ago
      fm.mobile = "9988776658"
    end
    puts "  ✓ Added family members for Sneha Patel"
  end
end

# 8. Create Health Insurance Policies
def create_health_insurance_policies
  puts "\n🏥 Creating Health Insurance Policies..."

  customers = Customer.where(customer_type: 'individual').limit(5)
  sub_agents = SubAgent.limit(3)
  brokers = Broker.limit(3)
  agency_codes = AgencyCode.where(insurance_type: 'Health')

  health_policies_data = [
    {
      customer_email: "john.doe@test.com",
      plan_name: "Star Family Health Optima",
      insurance_company_name: "Star Health Insurance",
      policy_type: "New",
      insurance_type: "Family Floater",
      policy_number: "SH#{rand(10000..99999)}",
      sum_insured: 500000,
      net_premium: 15000,
      total_premium: 17700, # Including 18% GST
      payment_mode: "Yearly",
      policy_start_date: 2.months.ago,
      policy_end_date: 10.months.from_now,
      gst_percentage: 18
    },
    {
      customer_email: "priya.sharma@test.com",
      plan_name: "HDFC ERGO Health Suraksha",
      insurance_company_name: "HDFC ERGO Health Insurance",
      policy_type: "New",
      insurance_type: "Individual",
      policy_number: "HE#{rand(10000..99999)}",
      sum_insured: 300000,
      net_premium: 8500,
      total_premium: 10030,
      payment_mode: "Yearly",
      policy_start_date: 1.month.ago,
      policy_end_date: 11.months.from_now,
      gst_percentage: 18
    },
    {
      customer_email: "rajesh.kumar@test.com",
      plan_name: "Care Health Insurance Supreme",
      insurance_company_name: "Care Health Insurance",
      policy_type: "Renewal",
      insurance_type: "Family Floater",
      policy_number: "CH#{rand(10000..99999)}",
      sum_insured: 1000000,
      net_premium: 25000,
      total_premium: 29500,
      payment_mode: "Yearly",
      policy_start_date: 3.months.ago,
      policy_end_date: 9.months.from_now,
      gst_percentage: 18
    },
    {
      customer_email: "sneha.patel@test.com",
      plan_name: "Niva Bupa Health Companion",
      insurance_company_name: "Niva Bupa Health Insurance",
      policy_type: "New",
      insurance_type: "Individual",
      policy_number: "NB#{rand(10000..99999)}",
      sum_insured: 200000,
      net_premium: 6500,
      total_premium: 7670,
      payment_mode: "Half-Yearly",
      policy_start_date: 15.days.ago,
      policy_end_date: 350.days.from_now,
      gst_percentage: 18
    },
    {
      customer_email: "vikash.gupta@test.com",
      plan_name: "Star Young Star Insurance",
      insurance_company_name: "Star Health Insurance",
      policy_type: "New",
      insurance_type: "Individual",
      policy_number: "SY#{rand(10000..99999)}",
      sum_insured: 300000,
      net_premium: 4500,
      total_premium: 5310,
      payment_mode: "Yearly",
      policy_start_date: 45.days.ago,
      policy_end_date: 320.days.from_now,
      gst_percentage: 18
    }
  ]

  health_policies_data.each_with_index do |policy_data, index|
    customer = Customer.find_by(email: policy_data[:customer_email])
    next unless customer

    # Assign sub-agent and broker cyclically
    sub_agent = sub_agents[index % sub_agents.count] if sub_agents.any?
    broker = brokers[index % brokers.count] if brokers.any?
    agency_code = agency_codes[index % agency_codes.count] if agency_codes.any?

    policy = HealthInsurance.find_or_create_by(policy_number: policy_data[:policy_number]) do |hi|
      hi.customer = customer
      hi.sub_agent = sub_agent
      hi.broker = broker
      hi.agency_code = agency_code
      hi.policy_holder = "Self"
      hi.plan_name = policy_data[:plan_name]
      hi.insurance_company_name = policy_data[:insurance_company_name]
      hi.policy_type = policy_data[:policy_type]
      hi.insurance_type = policy_data[:insurance_type]
      hi.sum_insured = policy_data[:sum_insured]
      hi.net_premium = policy_data[:net_premium]
      hi.total_premium = policy_data[:total_premium]
      hi.payment_mode = policy_data[:payment_mode]
      hi.policy_booking_date = policy_data[:policy_start_date]
      hi.policy_start_date = policy_data[:policy_start_date]
      hi.policy_end_date = policy_data[:policy_end_date]
      hi.gst_percentage = policy_data[:gst_percentage]
      hi.main_agent_commission_percentage = 15.0
      hi.commission_amount = policy_data[:net_premium] * 0.15
      hi.tds_percentage = 5.0
      hi.tds_amount = hi.commission_amount * 0.05
      hi.after_tds_value = hi.commission_amount - hi.tds_amount
    end
    puts "  ✓ Created health policy: #{policy.policy_number} for #{customer.display_name}"
  end
end

# 9. Create Life Insurance Policies
def create_life_insurance_policies
  puts "\n🛡️ Creating Life Insurance Policies..."

  customers = Customer.where(customer_type: 'individual').limit(5)
  sub_agents = SubAgent.limit(3)
  brokers = Broker.limit(3)
  agency_codes = AgencyCode.where(insurance_type: 'Life')

  life_policies_data = [
    {
      customer_email: "john.doe@test.com",
      plan_name: "LIC Jeevan Anand",
      insurance_company_name: "LIC of India",
      policy_type: "New",
      policy_number: "LIC#{rand(100000..999999)}",
      sum_insured: 1000000,
      net_premium: 50000,
      total_premium: 59000, # Including GST
      policy_term: 20,
      premium_payment_term: 15,
      payment_mode: "Yearly",
      policy_start_date: 6.months.ago,
      policy_end_date: 19.years.from_now + 6.months,
      nominee_name: "Jane Doe",
      nominee_relationship: "spouse",
      first_year_gst_percentage: 18
    },
    {
      customer_email: "priya.sharma@test.com",
      plan_name: "HDFC Life Click 2 Protect Plus",
      insurance_company_name: "HDFC Life Insurance",
      policy_type: "New",
      policy_number: "HD#{rand(100000..999999)}",
      sum_insured: 500000,
      net_premium: 8500,
      total_premium: 10030,
      policy_term: 30,
      premium_payment_term: 10,
      payment_mode: "Yearly",
      policy_start_date: 2.months.ago,
      policy_end_date: 29.years.from_now + 10.months,
      nominee_name: "Raj Sharma",
      nominee_relationship: "father",
      first_year_gst_percentage: 18
    },
    {
      customer_email: "rajesh.kumar@test.com",
      plan_name: "ICICI Prudential iProtect Smart",
      insurance_company_name: "ICICI Prudential Life Insurance",
      policy_type: "New",
      policy_number: "IC#{rand(100000..999999)}",
      sum_insured: 2000000,
      net_premium: 35000,
      total_premium: 41300,
      policy_term: 25,
      premium_payment_term: 20,
      payment_mode: "Yearly",
      policy_start_date: 8.months.ago,
      policy_end_date: 24.years.from_now + 4.months,
      nominee_name: "Sunita Kumar",
      nominee_relationship: "spouse",
      first_year_gst_percentage: 18
    },
    {
      customer_email: "vikash.gupta@test.com",
      plan_name: "SBI Life Shield",
      insurance_company_name: "SBI Life Insurance",
      policy_type: "New",
      policy_number: "SB#{rand(100000..999999)}",
      sum_insured: 750000,
      net_premium: 12000,
      total_premium: 14160,
      policy_term: 20,
      premium_payment_term: 15,
      payment_mode: "Yearly",
      policy_start_date: 1.month.ago,
      policy_end_date: 19.years.from_now + 11.months,
      nominee_name: "Maya Gupta",
      nominee_relationship: "mother",
      first_year_gst_percentage: 18
    }
  ]

  life_policies_data.each_with_index do |policy_data, index|
    customer = Customer.find_by(email: policy_data[:customer_email])
    next unless customer

    # Assign sub-agent and broker cyclically
    sub_agent = sub_agents[index % sub_agents.count] if sub_agents.any?
    broker = brokers[index % brokers.count] if brokers.any?
    agency_code = agency_codes[index % agency_codes.count] if agency_codes.any?

    policy = LifeInsurance.find_or_create_by(policy_number: policy_data[:policy_number]) do |li|
      li.customer = customer
      li.sub_agent = sub_agent
      li.broker = broker
      li.agency_code = agency_code
      li.policy_holder = "Self"
      li.plan_name = policy_data[:plan_name]
      li.insurance_company_name = policy_data[:insurance_company_name]
      li.policy_type = policy_data[:policy_type]
      li.sum_insured = policy_data[:sum_insured]
      li.net_premium = policy_data[:net_premium]
      li.total_premium = policy_data[:total_premium]
      li.policy_term = policy_data[:policy_term]
      li.premium_payment_term = policy_data[:premium_payment_term]
      li.payment_mode = policy_data[:payment_mode]
      li.policy_booking_date = policy_data[:policy_start_date]
      li.policy_start_date = policy_data[:policy_start_date]
      li.policy_end_date = policy_data[:policy_end_date]
      li.nominee_name = policy_data[:nominee_name]
      li.nominee_relationship = policy_data[:nominee_relationship]
      li.first_year_gst_percentage = policy_data[:first_year_gst_percentage]
      li.main_agent_commission_percentage = 20.0
      li.commission_amount = policy_data[:net_premium] * 0.20
      li.tds_percentage = 5.0
      li.tds_amount = li.commission_amount * 0.05
      li.after_tds_value = li.commission_amount - li.tds_amount
    end
    puts "  ✓ Created life policy: #{policy.policy_number} for #{customer.display_name}"
  end
end

# 10. Generate Statistics Summary
def generate_summary
  puts "\n📊 MOCK DATA GENERATION SUMMARY"
  puts "=" * 60

  puts "🏢 Company Data:"
  puts "  - Brokers: #{Broker.count}"
  puts "  - Agency Codes: #{AgencyCode.count}"

  puts "\n👤 User Data:"
  puts "  - Admin Users: #{User.where(user_type: 'admin').count}"
  puts "  - Agent Users: #{User.where(user_type: 'agent').count}"
  puts "  - Sub Agents: #{SubAgent.count}"

  puts "\n👥 Customer Data:"
  puts "  - Individual Customers: #{Customer.where(customer_type: 'individual').count}"
  puts "  - Corporate Customers: #{Customer.where(customer_type: 'corporate').count}"
  puts "  - Total Customers: #{Customer.count}"
  puts "  - Family Members: #{FamilyMember.count}"

  puts "\n🏥 Insurance Policies:"
  puts "  - Health Insurance Policies: #{HealthInsurance.count}"
  puts "  - Life Insurance Policies: #{LifeInsurance.count}"
  puts "  - Total Policies: #{HealthInsurance.count + LifeInsurance.count}"

  puts "\n💰 Financial Summary:"
  total_health_premium = HealthInsurance.sum(:total_premium)
  total_life_premium = LifeInsurance.sum(:total_premium)
  total_premium = total_health_premium + total_life_premium
  total_commission = HealthInsurance.sum(:commission_amount) + LifeInsurance.sum(:commission_amount)

  puts "  - Total Health Premium: ₹#{total_health_premium.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  puts "  - Total Life Premium: ₹#{total_life_premium.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  puts "  - Total Premium: ₹#{total_premium.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  puts "  - Total Commission: ₹#{total_commission.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"

  puts "\n🧪 Test Account Credentials:"
  puts "  Admin: admin@insurebook.com / password123"
  puts "  Agent 1: agent1@insurebook.com / password123"
  puts "  Agent 2: agent2@insurebook.com / password123"
  puts "  Manager: manager@insurebook.com / password123"

  puts "\n📱 Test Customer Login (for mobile app):"
  puts "  Customer 1: john.doe@test.com (no password - token based)"
  puts "  Customer 2: priya.sharma@test.com (no password - token based)"
  puts "  Customer 3: rajesh.kumar@test.com (no password - token based)"

  puts "\n✅ Mock data generation completed successfully!"
  puts "   You can now test all APIs with realistic data."
end

# Main execution
def run_mock_data_generation
  begin
    # Uncomment next line if you want to clear existing test data
    # clear_test_data

    create_insurance_companies
    create_brokers
    create_agency_codes
    create_users_and_agents
    create_sub_agents
    create_customers
    create_family_members
    create_health_insurance_policies
    create_life_insurance_policies
    generate_summary

  rescue => e
    puts "\n❌ Error during mock data generation:"
    puts "   #{e.message}"
    puts "   #{e.backtrace.first(3).join("\n   ")}"
  end
end

# Run the script
if __FILE__ == $0
  run_mock_data_generation
end