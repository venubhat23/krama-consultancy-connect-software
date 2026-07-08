#!/usr/bin/env ruby
# Generate Mock Data Script
# Run this in Rails console: load 'db/seeds/generate_mock_data.rb'

require 'securerandom'

puts "🚀 Starting mock data generation..."

# 0. Create Basic Role for Sub Agents if needed
puts "\n0. Setting up basic role..."
begin
  basic_role = UserRole.find_or_create_by(name: 'Sub Agent') do |role|
    role.description = 'Basic Sub Agent Role'
    role.status = true
    role.display_order = 1
  end
  puts "✅ Basic role created: #{basic_role.name}"
rescue => e
  puts "⚠️ Role creation skipped: #{e.message}"
  basic_role = nil
end

# 1. Create Admin User
puts "\n1. Creating Admin User..."
admin = User.find_or_create_by(email: 'admin@drwise.com') do |u|
  u.first_name = 'Admin'
  u.last_name = 'User'
  u.password = 'password123'
  u.password_confirmation = 'password123'
  u.mobile = '+919999999999'
  u.pan_number = 'ADMIN1234A'
  u.date_of_birth = '1980-01-01'
  u.gender = 'male'
  u.occupation = 'Administrator'
  u.annual_income = 1000000
  u.address = 'Admin Office, Mumbai'
  u.state = 'Maharashtra'
  u.city = 'Mumbai'
  u.user_type = 'admin'
  u.status = true
end

if admin.persisted?
  puts "✅ Admin user created: #{admin.email} / password123"
else
  puts "❌ Failed to create admin user: #{admin.errors.full_messages}"
end

# 2. Create Sub Agents
puts "\n2. Creating 30 Sub Agents..."
sub_agents = []

first_names = ['Amit', 'Priya', 'Rajesh', 'Sneha', 'Vikash', 'Pooja', 'Ravi', 'Anita', 'Suresh', 'Kavya', 'Manoj', 'Deepika', 'Sanjay', 'Neha', 'Arjun', 'Rohit', 'Simran', 'Karan', 'Meera', 'Atul', 'Shruti', 'Gopal', 'Rina', 'Mahesh', 'Seema', 'Ajay', 'Priti', 'Vikas', 'Nisha', 'Arun']
last_names = ['Sharma', 'Patel', 'Kumar', 'Singh', 'Gupta', 'Joshi', 'Verma', 'Agarwal', 'Mishra', 'Tiwari', 'Yadav', 'Pandey', 'Shah', 'Mehta', 'Jain', 'Malhotra', 'Kapoor', 'Sinha', 'Chopra', 'Bansal', 'Goel', 'Khanna', 'Bajaj', 'Sethi', 'Arora', 'Saxena', 'Goyal', 'Doshi', 'Modi', 'Iyer']

30.times do |i|
  first_name = first_names[i % first_names.length]
  last_name = last_names[i % last_names.length]

  sub_agent = SubAgent.find_or_create_by(email: "subagent#{i+1}@drwise.com") do |sa|
    sa.first_name = first_name
    sa.last_name = last_name
    sa.password = 'password123'
    sa.mobile = "9#{(100000000 + rand(899999999)).to_s}"
    sa.pan_no = "#{('A'..'Z').to_a.sample(5).join}#{(1000..9999).to_a.sample}#{('A'..'Z').to_a.sample}"
    sa.birth_date = Date.new(rand(1970..1995), rand(1..12), rand(1..28))
    sa.gender = ['Male', 'Female'].sample
    sa.address = "#{rand(1..999)} Main Street, Sector #{rand(1..50)}"
    sa.bank_name = ['HDFC Bank', 'ICICI Bank', 'SBI', 'Axis Bank'].sample
    sa.account_type = ['Savings', 'Current'].sample
    sa.account_no = (10000000000 + rand(89999999999)).to_s
    sa.ifsc_code = "#{['HDFC', 'ICIC', 'SBIN', 'UTIB'].sample}0#{(100000..999999).to_a.sample}"
    sa.account_holder_name = "#{first_name} #{last_name}"
    sa.role_id = basic_role&.id || 1
    sa.status = :active
  end

  sub_agents << sub_agent
  puts "✅ Sub Agent #{i+1}: #{sub_agent.first_name} #{sub_agent.last_name} (#{sub_agent.email})"
end

# 3. Create Customers
puts "\n3. Creating 50 Customers..."
customers = []

customer_first_names = ['Rahul', 'Preethi', 'Arjun', 'Sowmya', 'Karan', 'Meera', 'Rohit', 'Nidhi', 'Varun', 'Shreya', 'Aman', 'Ritika', 'Dev', 'Preeti', 'Sahil', 'Divya', 'Nitin', 'Swati', 'Kunal', 'Preya', 'Akash', 'Deepa', 'Harsh', 'Nikita', 'Ravi', 'Sunita', 'Anil', 'Geeta', 'Suraj', 'Priya', 'Vishal', 'Kavita', 'Raman', 'Shilpa', 'Ajit']
customer_last_names = ['Agrawal', 'Bhat', 'Reddy', 'Nair', 'Kapoor', 'Soni', 'Malhotra', 'Chopra', 'Bajaj', 'Sethi', 'Goel', 'Khanna', 'Bansal', 'Jain', 'Modi', 'Doshi', 'Goyal', 'Arora', 'Saxena', 'Iyer', 'Bhatt', 'Tiwari', 'Mishra', 'Yadav', 'Pandey', 'Shah', 'Mehta', 'Patel', 'Singh', 'Kumar', 'Gupta', 'Verma', 'Sharma', 'Joshi', 'Agarwal']
company_names = ['Tech Solutions Pvt Ltd', 'Digital Innovations', 'Global Enterprises', 'Smart Systems Ltd', 'Future Technologies', 'Prime Industries', 'Elite Services', 'Modern Solutions', 'Advanced Systems', 'Supreme Holdings', 'Infinity Corp', 'Nexus Tech', 'Alpha Industries', 'Beta Systems', 'Gamma Solutions']
job_titles = ['Software Engineer', 'Manager', 'Doctor', 'Teacher', 'Businessman', 'Consultant', 'Accountant', 'Designer', 'Sales Executive', 'Marketing Manager', 'Analyst', 'Engineer', 'Director', 'Executive', 'Specialist']

50.times do |i|
  customer_type = i < 35 ? 'individual' : 'corporate' # 35 individual, 15 corporate

  if customer_type == 'individual'
    first_name = customer_first_names[i % customer_first_names.length]
    last_name = customer_last_names[i % customer_last_names.length]
    company_name = nil
    display_name = "#{first_name} #{last_name}"
  else
    first_name = nil
    last_name = nil
    company_name = "#{company_names[i % company_names.length]} #{i - 34}"
    display_name = company_name
  end

  customer = Customer.create!(
    customer_type: customer_type,
    first_name: first_name,
    last_name: last_name,
    company_name: company_name,
    email: "customer#{i+1}@example.com",
    mobile: "9#{(100000000 + rand(899999999)).to_s}",
    gender: customer_type == 'individual' ? ['male', 'female'].sample : nil,
    birth_date: customer_type == 'individual' ? Date.new(rand(1950..2000), rand(1..12), rand(1..28)) : nil,
    address: "#{rand(100..999)} #{['MG Road', 'Park Street', 'Commercial Street', 'Brigade Road'].sample}, #{['Sector', 'Block', 'Area'].sample} #{rand(1..50)}",
    city: ['Mumbai', 'Delhi', 'Bangalore', 'Chennai', 'Hyderabad', 'Pune', 'Kolkata', 'Gurgaon', 'Noida'].sample,
    state: ['Maharashtra', 'Delhi', 'Karnataka', 'Tamil Nadu', 'Telangana', 'West Bengal', 'Haryana', 'Uttar Pradesh'].sample,
    pincode: (100001 + rand(699999)).to_s,
    pan_no: "#{('A'..'Z').to_a.sample(5).join}#{(1000..9999).to_a.sample}#{('A'..'Z').to_a.sample}",
    gst_no: nil, # Skip GST number to avoid validation issues
    occupation: job_titles.sample,
    annual_income: [300000, 500000, 750000, 1000000, 1500000, 2000000].sample,
    marital_status: customer_type == 'individual' ? ['single', 'married', 'divorced'].sample : nil,
    status: true,
    added_by: 'system_seed'
  )

  customers << customer
  puts "✅ Customer #{i+1}: #{display_name} (#{customer.customer_type})"
end

# 4. Create Health Insurance Policies
puts "\n4. Creating 35 Health Insurance Policies..."

insurance_companies = [
  'Bajaj Allianz General Insurance Company Limited',
  'HDFC ERGO General Insurance Co Ltd',
  'Care Health Insurance Ltd',
  'Star Health Allied Insurance Co Ltd',
  'Aditya Birla Health Insurance Co Ltd',
  'Niva Bupa Health Insurance Co Ltd',
  'Manipal Cigna Health Insurance Company Limited',
  'National Insurance Co Ltd'
]

plan_names = [
  'Family Health Plus',
  'Individual Health Care',
  'Senior Citizen Plan',
  'Corporate Group Health',
  'Critical Care Plus',
  'Super Top Up',
  'Personal Guard',
  'Health Companion'
]

35.times do |i|
  customer = customers.sample
  sub_agent = sub_agents.sample

  policy_start_date = Date.current - rand(365).days
  policy_end_date = policy_start_date + 1.year

  net_premium = [15000, 25000, 35000, 50000, 75000].sample
  gst_percentage = 18.0
  total_premium = net_premium + (net_premium * gst_percentage / 100.0)

  health_insurance = HealthInsurance.create!(
    customer: customer,
    sub_agent: sub_agent,
    policy_holder: customer.display_name,
    insurance_company_name: insurance_companies.sample,
    insurance_type: ['Individual', 'Family Floater', 'Group'].sample,
    policy_type: ['New', 'Renewal'].sample,
    policy_number: "HI#{Date.current.year}#{sprintf('%06d', rand(100000..999999))}",
    policy_booking_date: policy_start_date - rand(1..30).days,
    policy_start_date: policy_start_date,
    policy_end_date: policy_end_date,
    payment_mode: ['Yearly', 'Half-Yearly', 'Quarterly', 'Monthly'].sample,
    sum_insured: [300000, 500000, 1000000, 1500000, 2000000].sample,
    net_premium: net_premium,
    gst_percentage: gst_percentage,
    total_premium: total_premium,
    plan_name: plan_names.sample,
    commission_amount: (total_premium * 0.1), # 10% commission
    tds_percentage: 10.0,
    tds_amount: (total_premium * 0.1 * 0.1),
    after_tds_value: (total_premium * 0.1 * 0.9),
    is_agent_added: true,
    is_customer_added: false,
    is_admin_added: false
  )

  puts "✅ Health Insurance #{i+1}: #{health_insurance.policy_number} - #{customer.display_name}"
end

# 5. Create sample Distributors and Investors
puts "\n5. Creating sample Distributors and Investors..."

# Create sample distributors
3.times do |i|
  Distributor.find_or_create_by(email: "distributor#{i+1}@drwise.com") do |d|
    d.first_name = "Distributor"
    d.last_name = "#{i+1}"
    d.mobile = "9#{(100000000 + rand(899999999)).to_s}"
    d.status = :active
  end
end

# Create sample investors
3.times do |i|
  Investor.find_or_create_by(email: "investor#{i+1}@drwise.com") do |inv|
    inv.first_name = "Investor"
    inv.last_name = "#{i+1}"
    inv.mobile = "9#{(100000000 + rand(899999999)).to_s}"
    inv.status = :active
  end
end

puts "✅ Created sample distributors and investors"

# 6. Create Life Insurance Policies
puts "\n6. Creating 30 Life Insurance Policies..."

life_plan_names = [
  'LIC Jeevan Anand',
  'Term Life Plus',
  'Endowment Plan',
  'ULIP Growth',
  'Pension Plan Plus',
  'Money Back Policy',
  'Whole Life Insurance',
  'LIC New Jeevan Anand',
  'Term Assurance Plan',
  'Investment Plus'
]

30.times do |i|
  customer = customers.sample
  sub_agent = sub_agents.sample
  distributor = Distributor.all.sample
  investor = Investor.all.sample

  policy_start_date = Date.current - rand(365).days
  policy_term_years = [10, 15, 20, 25, 30].sample
  policy_end_date = policy_start_date + policy_term_years.years

  net_premium = [12000, 18000, 25000, 35000, 50000].sample
  first_year_gst = 18.0
  total_premium = net_premium + (net_premium * first_year_gst / 100.0)

  life_insurance = LifeInsurance.create!(
    customer: customer,
    sub_agent: sub_agent,
    distributor: distributor,
    investor: investor,
    policy_holder: customer.display_name,
    insured_name: customer.display_name,
    insurance_company_name: insurance_companies.sample,
    policy_type: 'New',
    policy_number: "LI#{Date.current.year}#{sprintf('%06d', rand(100000..999999))}",
    policy_booking_date: policy_start_date - rand(1..30).days,
    policy_start_date: policy_start_date,
    policy_end_date: policy_end_date,
    policy_term: policy_term_years,
    premium_payment_term: [policy_term_years, policy_term_years - 5].min,
    payment_mode: ['Yearly', 'Half-Yearly', 'Quarterly', 'Monthly'].sample,
    sum_insured: [500000, 1000000, 1500000, 2000000, 2500000].sample,
    net_premium: net_premium,
    first_year_gst_percentage: first_year_gst,
    second_year_gst_percentage: 4.5,
    third_year_gst_percentage: 4.5,
    total_premium: total_premium,
    plan_name: life_plan_names.sample,
    commission_amount: (total_premium * 0.15), # 15% commission for life
    sub_agent_commission_percentage: 7.0,
    sub_agent_commission_amount: (total_premium * 0.07),
    sub_agent_tds_percentage: 10.0,
    sub_agent_tds_amount: (total_premium * 0.07 * 0.1),
    sub_agent_after_tds_value: (total_premium * 0.07 * 0.9),
    reference_by_name: ['Self', 'Friend', 'Family'].sample,
    is_agent_added: true,
    is_customer_added: false,
    is_admin_added: false
  )

  # Create nominee for life insurance
  nominee_names = ['Rahul Sharma', 'Priya Patel', 'Aman Kumar', 'Sneha Singh', 'Vikash Gupta', 'Pooja Joshi', 'Ravi Verma', 'Anita Agarwal']
  LifeInsuranceNominee.create!(
    life_insurance: life_insurance,
    nominee_name: nominee_names.sample,
    relationship: ['Spouse', 'Father', 'Mother', 'Son', 'Daughter', 'Brother', 'Sister'].sample,
    age: rand(18..65),
    share_percentage: 100.0
  )

  puts "✅ Life Insurance #{i+1}: #{life_insurance.policy_number} - #{customer.display_name}"
end

# 7. Create Commission Payouts
puts "\n7. Creating Commission Payouts..."

# Health insurance commission payouts
HealthInsurance.includes(:customer, :sub_agent).each do |policy|
  next unless policy.sub_agent

  # Create random commission payouts (some paid, some pending)
  status = ['paid', 'pending'].sample
  payout_date = status == 'paid' ? (policy.policy_start_date + rand((Date.current - policy.policy_start_date).to_i).days) : nil

  CommissionPayout.create!(
    policy_type: 'health',
    policy_id: policy.id,
    payout_to: 'sub_agent',
    payout_amount: policy.after_tds_value || 0,
    payout_date: payout_date,
    status: status
  )
end

# Life insurance commission payouts
LifeInsurance.includes(:customer, :sub_agent).each do |policy|
  next unless policy.sub_agent

  status = ['paid', 'pending'].sample
  payout_date = status == 'paid' ? (policy.policy_start_date + rand((Date.current - policy.policy_start_date).to_i).days) : nil

  CommissionPayout.create!(
    policy_type: 'life',
    policy_id: policy.id,
    payout_to: 'sub_agent',
    payout_amount: policy.sub_agent_after_tds_value || 0,
    payout_date: payout_date,
    status: status
  )
end

puts "✅ Commission payouts created"

# 8. Create Leads
puts "\n8. Creating 40 Leads..."

lead_names = ['Sanjay Kapoor', 'Neha Sharma', 'Rajesh Kumar', 'Preethi Nair', 'Ashok Patel', 'Divya Singh', 'Manoj Gupta', 'Kavya Reddy', 'Suresh Joshi', 'Anita Verma', 'Ramesh Agarwal', 'Pooja Mishra', 'Kiran Tiwari', 'Shreya Yadav', 'Varun Pandey', 'Meera Shah', 'Nitin Mehta', 'Swati Jain', 'Rohit Modi', 'Nidhi Doshi', 'Aman Goyal', 'Ritika Khanna', 'Dev Bansal', 'Preeti Sethi', 'Sahil Goel', 'Ravi Tomar', 'Sita Devi', 'Arjun Rao', 'Sunita Jain', 'Vivek Singh', 'Reema Patel', 'Hitesh Shah', 'Priyanka Gupta', 'Manish Kumar', 'Deepika Reddy', 'Vinod Sharma', 'Kaveri Nair', 'Satish Verma', 'Anjali Mishra', 'Rakesh Joshi']

40.times do |i|
  lead = Lead.create!(
    name: lead_names[i % lead_names.length],
    contact_number: "9#{(100000000 + rand(899999999)).to_s}",
    email: "lead#{i+1}@example.com",
    product_interest: ['health', 'life', 'motor', 'other'].sample,
    address: "#{rand(100..999)} #{['MG Road', 'Park Street', 'Commercial Street'].sample}, #{['Sector', 'Block'].sample} #{rand(1..50)}",
    city: ['Mumbai', 'Delhi', 'Bangalore', 'Chennai', 'Hyderabad', 'Pune'].sample,
    state: ['Maharashtra', 'Delhi', 'Karnataka', 'Tamil Nadu', 'Telangana'].sample,
    referred_by: ['Rahul Sharma', 'Walk-in', 'Online', 'Advertisement', 'Friend Referral'].sample,
    current_stage: ['consultation', 'one_on_one', 'converted', 'policy_created'].sample,
    created_date: Date.current - rand(90).days,
    notes: "Interested in #{['family health coverage', 'term life insurance', 'comprehensive motor insurance', 'other insurance'].sample}",
    lead_source: ['online', 'offline', 'agent_referral', 'walk_in', 'tele_calling', 'campaign'].sample,
    referral_amount: [1000, 2000, 3000, 5000].sample,
    transferred_amount: [true, false].sample,
    stage_updated_at: Time.current
  )

  puts "✅ Lead #{i+1}: #{lead.name} - #{lead.product_interest}"
end

# 9. Update customer policies count
puts "\n9. Updating customer policies count..."
Customer.find_each do |customer|
  policies_count = HealthInsurance.where(customer: customer).count +
                   LifeInsurance.where(customer: customer).count
  customer.update_column(:policies_count, policies_count)
end

# Summary
puts "\n" + "="*50
puts "🎉 MOCK DATA GENERATION COMPLETED!"
puts "="*50

puts "\n📊 SUMMARY:"
puts "👤 Admin Users: #{User.where(user_type: 'admin').count}"
puts "🏢 Sub Agents: #{SubAgent.count}"
puts "👥 Customers: #{Customer.count}"
puts "🏥 Health Insurance Policies: #{HealthInsurance.count}"
puts "💰 Life Insurance Policies: #{LifeInsurance.count}"
puts "💳 Commission Payouts: #{CommissionPayout.count}"
puts "🎯 Leads: #{Lead.count}"

puts "\n🔑 LOGIN CREDENTIALS:"
puts "Admin Email: admin@drwise.com"
puts "Password: password123"

puts "\n📧 Sub Agent Emails (all with password123):"
SubAgent.limit(5).each do |agent|
  puts "- #{agent.email}"
end
puts "... and #{SubAgent.count - 5} more sub-agents"

puts "\n✅ All data generated successfully!"
puts "You can now test the mobile APIs with the created data."