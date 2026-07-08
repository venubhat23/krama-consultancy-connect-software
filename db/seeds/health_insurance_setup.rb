# Health Insurance Module Sample Data Setup

puts "🏥 Setting up Health Insurance Module sample data..."

# Create sample brokers
brokers_data = [
  { name: "HDFC ERGO Broker", status: "active" },
  { name: "Star Health Broker", status: "active" },
  { name: "Care Health Broker", status: "active" },
  { name: "Bajaj Allianz Broker", status: "active" }
]

puts "Creating sample brokers..."
brokers_data.each do |broker_data|
  broker = Broker.find_or_create_by(name: broker_data[:name]) do |b|
    b.status = broker_data[:status]
  end
  puts "✓ Created broker: #{broker.name}"
end

# Create sample agency codes
agency_codes_data = [
  {
    insurance_type: 'Health',
    company_name: 'Star Health Allied Insurance Co Ltd',
    agent_name: 'Bharath D',
    code: 'BA000424798'
  },
  {
    insurance_type: 'Health',
    company_name: 'HDFC ERGO General Insurance Co Ltd',
    agent_name: 'Rajesh Kumar',
    code: 'RK000567123'
  },
  {
    insurance_type: 'Health',
    company_name: 'Care Health Insurance Ltd',
    agent_name: 'Priya Sharma',
    code: 'PS000789456'
  },
  {
    insurance_type: 'Health',
    company_name: 'Bajaj Allianz General Insurance Company Limited',
    agent_name: 'Amit Singh',
    code: 'AS000234567'
  },
  {
    insurance_type: 'Health',
    company_name: 'Niva Bupa Health Insurance Co Ltd',
    agent_name: 'Sunita Reddy',
    code: 'SR000345678'
  }
]

puts "Creating sample agency codes..."
agency_codes_data.each do |code_data|
  agency_code = AgencyCode.find_or_create_by(
    company_name: code_data[:company_name],
    code: code_data[:code]
  ) do |ac|
    ac.insurance_type = code_data[:insurance_type]
    ac.agent_name = code_data[:agent_name]
  end
  puts "✓ Created agency code: #{agency_code.code} for #{agency_code.company_name}"
end

# Create sample customers for testing
customers_data = [
  {
    customer_type: 'individual',
    first_name: 'Rajesh',
    last_name: 'Kumar',
    email: 'rajesh.kumar@email.com',
    mobile: '9876543210',
    birth_date: Date.parse('1985-05-15'),
    gender: 'male',
    marital_status: 'married',
    pan_no: 'ABCDE1234F',
    status: true
  },
  {
    customer_type: 'individual',
    first_name: 'Priya',
    last_name: 'Sharma',
    email: 'priya.sharma@email.com',
    mobile: '9876543211',
    birth_date: Date.parse('1990-08-22'),
    gender: 'female',
    marital_status: 'single',
    pan_no: 'FGHIJ5678K',
    status: true
  },
  {
    customer_type: 'corporate',
    company_name: 'Tech Solutions Pvt Ltd',
    email: 'hr@techsolutions.com',
    mobile: '9876543212',
    pan_no: 'KLMNO9012P',
    gst_no: '29KLMNO9012P1ZX',
    status: true
  }
]

puts "Creating sample customers..."
customers_data.each do |customer_data|
  customer = Customer.find_or_create_by(email: customer_data[:email]) do |c|
    customer_data.each { |key, value| c.send("#{key}=", value) }
  end
  puts "✓ Created customer: #{customer.display_name}"

  # Add family members for individual customers
  if customer.individual? && customer.marital_status == 'married'
    family_members_data = [
      {
        relationship: 'Spouse',
        first_name: customer.first_name == 'Rajesh' ? 'Sunita' : 'Amit',
        last_name: customer.last_name,
        birth_date: customer.birth_date + 2.years,
        gender: customer.gender == 'male' ? 'female' : 'male'
      },
      {
        relationship: 'Son',
        first_name: 'Arjun',
        last_name: customer.last_name,
        birth_date: Date.current - 10.years,
        gender: 'male'
      }
    ]

    family_members_data.each do |member_data|
      member = customer.family_members.find_or_create_by(
        relationship: member_data[:relationship],
        first_name: member_data[:first_name]
      ) do |fm|
        member_data.each { |key, value| fm.send("#{key}=", value) }
      end
      puts "  ✓ Added family member: #{member.full_name} (#{member.relationship})"
    end
  end
end

# Create sample sub agents
sub_agents_data = [
  {
    first_name: 'Manoj',
    last_name: 'Verma',
    email: 'manoj.verma@email.com',
    mobile: '9876543213',
    role_id: 1,
    status: 'active',
    gender: 'Male'
  },
  {
    first_name: 'Kavita',
    last_name: 'Singh',
    email: 'kavita.singh@email.com',
    mobile: '9876543214',
    role_id: 2,
    status: 'active',
    gender: 'Female'
  }
]

puts "Creating sample sub agents..."
sub_agents_data.each do |agent_data|
  agent = SubAgent.find_or_create_by(email: agent_data[:email]) do |sa|
    agent_data.each { |key, value| sa.send("#{key}=", value) }
  end
  puts "✓ Created sub agent: #{agent.display_name}"
end

# Create sample health insurance policies
if Customer.any? && AgencyCode.any?
  puts "Creating sample health insurance policies..."

  customers = Customer.limit(2)
  agency_code = AgencyCode.first
  broker = Broker.first
  sub_agent = SubAgent.first

  customers.each_with_index do |customer, index|
    policy_data = {
      customer: customer,
      sub_agent: index == 0 ? sub_agent : nil,
      agency_code: agency_code,
      broker: broker,
      policy_holder: 'Self',
      insurance_company_name: 'Star Health Allied Insurance Co Ltd',
      policy_type: 'New',
      insurance_type: customer.individual? && customer.family_members.any? ? 'Family Floater' : 'Individual',
      plan_name: 'Star Comprehensive Health Policy',
      policy_number: "SH#{Date.current.year}#{sprintf('%06d', index + 1)}",
      policy_booking_date: Date.current - rand(30).days,
      policy_start_date: Date.current,
      policy_end_date: Date.current + 1.year - 1.day,
      payment_mode: ['Yearly', 'Half Yearly'].sample,
      sum_insured: [500000, 1000000, 1500000].sample,
      net_premium: rand(15000..50000),
      gst_percentage: 18,
      main_agent_commission_percentage: rand(5..15),
      tds_percentage: 5,
      claim_process: 'Network hospital: Cashless treatment. Reimbursement: Submit bills within 30 days.'
    }

    # Calculate derived fields
    policy_data[:policy_term] = (policy_data[:policy_end_date] - policy_data[:policy_start_date]).to_i / 365
    gst_amount = policy_data[:net_premium] * (policy_data[:gst_percentage] / 100.0)
    policy_data[:total_premium] = policy_data[:net_premium] + gst_amount

    commission_amount = policy_data[:net_premium] * (policy_data[:main_agent_commission_percentage] / 100.0)
    policy_data[:commission_amount] = commission_amount

    tds_amount = commission_amount * (policy_data[:tds_percentage] / 100.0)
    policy_data[:tds_amount] = tds_amount
    policy_data[:after_tds_value] = commission_amount - tds_amount

    health_insurance = HealthInsurance.find_or_create_by(
      policy_number: policy_data[:policy_number]
    ) do |hi|
      policy_data.each { |key, value| hi.send("#{key}=", value) }
    end

    puts "✓ Created health insurance policy: #{health_insurance.policy_number} for #{customer.display_name}"

    # Add family members if it's a family floater policy
    if health_insurance.insurance_type == 'Family Floater' && customer.family_members.any?
      customer.family_members.each do |family_member|
        member = health_insurance.health_insurance_members.find_or_create_by(
          member_name: family_member.full_name
        ) do |him|
          him.age = family_member.age || ((Date.current - family_member.birth_date).to_i / 365) if family_member.birth_date
          him.relationship = family_member.relationship
          him.sum_insured = health_insurance.sum_insured
        end
        puts "  ✓ Added family member to policy: #{member.member_name} (#{member.relationship})"
      end
    end
  end
end

puts "🎉 Health Insurance Module sample data setup completed!"
puts ""
puts "📊 Summary:"
puts "- Brokers: #{Broker.count}"
puts "- Agency Codes: #{AgencyCode.count}"
puts "- Customers: #{Customer.count}"
puts "- Sub Agents: #{SubAgent.count}"
puts "- Health Insurance Policies: #{HealthInsurance.count}"
puts "- Health Insurance Members: #{HealthInsuranceMember.count}"
puts ""
puts "You can now test the Health Insurance module with realistic data!"