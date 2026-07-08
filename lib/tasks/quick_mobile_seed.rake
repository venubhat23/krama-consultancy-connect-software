namespace :mobile_api do
  desc 'Quick seed data for mobile APIs with upcoming installments'
  task quick_seed: :environment do
    puts "🚀 Starting quick mobile API seed data creation..."

    # Clean existing test data
    puts "🧹 Cleaning existing test data..."
    HealthInsuranceMember.where("member_name LIKE ?", "%Customer%").destroy_all
    HealthInsurance.where("policy_number LIKE ?", "HLT%TEST%").destroy_all
    LifeInsurance.where("policy_number LIKE ?", "LIF%TEST%").destroy_all
    Customer.where("email LIKE ?", "%@example.com").destroy_all

    # Create test customer for upcoming installments
    puts "👤 Creating test customer..."
    test_customer = Customer.create!(
      customer_type: 'individual',
      first_name: "TestInstallment",
      last_name: "Customer",
      email: "installment.test@example.com",
      mobile: "9876543210",
      address: "Test Address, Mumbai",
      state: "Maharashtra",
      city: "Mumbai",
      pincode: "400001",
      birth_date: 30.years.ago,
      age: 30,
      gender: 'male',
      education: 'Graduate',
      marital_status: 'married',
      occupation: 'Service',
      annual_income: 600000,
      pan_number: "TESTPN123F",
      status: true,
      added_by: "admin"
    )

    # Create 2-3 family members
    puts "👨‍👩‍👧 Creating family members..."
    FamilyMember.create!(
      customer: test_customer,
      first_name: "TestSpouse",
      last_name: "Customer",
      birth_date: 28.years.ago,
      age: 28,
      gender: 'female',
      relationship: 'spouse',
      mobile: "9876543211"
    )

    FamilyMember.create!(
      customer: test_customer,
      first_name: "TestChild1",
      last_name: "Customer",
      birth_date: 5.years.ago,
      age: 5,
      gender: 'male',
      relationship: 'child',
      mobile: "9876543212"
    )

    # Create Health Insurance with upcoming monthly installments
    puts "🏥 Creating Health Insurance with upcoming installments..."
    health_policy = HealthInsurance.create!(
      customer: test_customer,
      policy_holder: test_customer.display_name,
      insurance_company_name: "Star Health Allied Insurance Co Ltd",
      plan_name: "Family Health Protection Plan",
      policy_number: "HLT_MONTHLY_TEST_#{Time.current.to_i}",
      insurance_type: 'Individual',
      policy_type: 'New',
      policy_booking_date: 6.months.ago,
      policy_start_date: 6.months.ago,
      policy_end_date: 6.months.from_now,
      payment_mode: 'Monthly',
      sum_insured: 500000,
      net_premium: 24000,
      gst_percentage: 18,
      total_premium: 28320,
      main_agent_commission_percentage: 20,
      commission_amount: 4800,
      tds_percentage: 10,
      tds_amount: 480,
      after_tds_value: 4320,
      # Key field for upcoming installments
      installment_autopay_start_date: 5.days.from_now,
      installment_autopay_end_date: 6.months.from_now
    )

    # Create Health Insurance with quarterly installments
    HealthInsurance.create!(
      customer: test_customer,
      policy_holder: test_customer.display_name,
      insurance_company_name: "Care Health Insurance Ltd",
      plan_name: "Quarterly Health Plan",
      policy_number: "HLT_QUARTERLY_TEST_#{Time.current.to_i}",
      insurance_type: 'Family Floater',
      policy_type: 'Renewal',
      policy_booking_date: 8.months.ago,
      policy_start_date: 8.months.ago,
      policy_end_date: 4.months.from_now,
      payment_mode: 'Quarterly',
      sum_insured: 1000000,
      net_premium: 36000,
      gst_percentage: 18,
      total_premium: 42480,
      main_agent_commission_percentage: 22,
      commission_amount: 7920,
      installment_autopay_start_date: 10.days.from_now,
      installment_autopay_end_date: 4.months.from_now
    )

    # Create Life Insurance with upcoming monthly installments
    puts "👨‍👩‍👧‍👦 Creating Life Insurance with upcoming installments..."
    LifeInsurance.create!(
      customer: test_customer,
      policy_holder: test_customer.display_name,
      insured_name: test_customer.display_name,
      insurance_company_name: "ICICI Prudential Life Insurance Co Ltd",
      plan_name: "Term Life Protection Plan",
      policy_number: "LIF_MONTHLY_TEST_#{Time.current.to_i}",
      policy_type: 'New',
      policy_booking_date: 1.year.ago,
      policy_start_date: 1.year.ago,
      policy_end_date: 19.years.from_now,
      policy_term: 20,
      premium_payment_term: 15,
      payment_mode: 'Monthly',
      sum_insured: 2000000,
      net_premium: 60000,
      first_year_gst_percentage: 18,
      second_year_gst_percentage: 0,
      third_year_gst_percentage: 0,
      total_premium: 70800,
      nominee_name: "TestSpouse Customer",
      nominee_relationship: 'Spouse',
      nominee_age: 28,
      main_agent_commission_percentage: 25,
      commission_amount: 15000,
      tds_percentage: 10,
      tds_amount: 1500,
      after_tds_value: 13500,
      # Key field for upcoming installments
      installment_autopay_start_date: 2.days.from_now,
      installment_autopay_end_date: 14.years.from_now,
      active: true
    )

    # Create policies for upcoming renewals
    puts "🔄 Creating policies for upcoming renewals..."

    # Health insurance expiring in 15 days
    HealthInsurance.create!(
      customer: test_customer,
      policy_holder: test_customer.display_name,
      insurance_company_name: "HDFC ERGO General Insurance Co Ltd",
      plan_name: "Health Plan Expiring Soon",
      policy_number: "HLT_EXPIRING_TEST_#{Time.current.to_i}",
      insurance_type: 'Individual',
      policy_type: 'Renewal',
      policy_booking_date: 11.months.ago,
      policy_start_date: 11.months.ago,
      policy_end_date: 15.days.from_now, # Expiring soon for renewals API
      payment_mode: 'Yearly',
      sum_insured: 750000,
      net_premium: 30000,
      gst_percentage: 18,
      total_premium: 35400,
      main_agent_commission_percentage: 18,
      commission_amount: 5400
    )

    # Life insurance expiring in 45 days
    LifeInsurance.create!(
      customer: test_customer,
      policy_holder: test_customer.display_name,
      insured_name: test_customer.display_name,
      insurance_company_name: "ICICI Prudential Life Insurance Co Ltd",
      plan_name: "Life Plan Expiring Soon",
      policy_number: "LIF_EXPIRING_TEST_#{Time.current.to_i}",
      policy_type: 'Renewal',
      policy_booking_date: 10.years.ago,
      policy_start_date: 10.years.ago,
      policy_end_date: 45.days.from_now, # Expiring soon for renewals API
      policy_term: 10,
      premium_payment_term: 10,
      payment_mode: 'Yearly',
      sum_insured: 1500000,
      net_premium: 45000,
      first_year_gst_percentage: 18,
      total_premium: 53100,
      nominee_name: "TestSpouse Customer",
      nominee_relationship: 'Spouse',
      nominee_age: 28,
      main_agent_commission_percentage: 20,
      commission_amount: 9000,
      active: true
    )

    # Create some active policies for portfolio
    puts "📋 Creating active policies for portfolio..."

    # Active Health Insurance
    HealthInsurance.create!(
      customer: test_customer,
      policy_holder: test_customer.display_name,
      insurance_company_name: "Niva Bupa Health Insurance Co Ltd",
      plan_name: "Active Family Health Plan",
      policy_number: "HLT_ACTIVE_TEST_#{Time.current.to_i}",
      insurance_type: 'Family Floater',
      policy_type: 'New',
      policy_booking_date: 3.months.ago,
      policy_start_date: 3.months.ago,
      policy_end_date: 9.months.from_now,
      payment_mode: 'Yearly',
      sum_insured: 800000,
      net_premium: 32000,
      gst_percentage: 18,
      total_premium: 37760,
      main_agent_commission_percentage: 20,
      commission_amount: 6400
    )

    # Active Life Insurance
    LifeInsurance.create!(
      customer: test_customer,
      policy_holder: test_customer.display_name,
      insured_name: test_customer.display_name,
      insurance_company_name: "ICICI Prudential Life Insurance Co Ltd",
      plan_name: "Active Life Protection Plan",
      policy_number: "LIF_ACTIVE_TEST_#{Time.current.to_i}",
      policy_type: 'New',
      policy_booking_date: 2.years.ago,
      policy_start_date: 2.years.ago,
      policy_end_date: 18.years.from_now,
      policy_term: 20,
      premium_payment_term: 15,
      payment_mode: 'Yearly',
      sum_insured: 3000000,
      net_premium: 80000,
      first_year_gst_percentage: 18,
      total_premium: 94400,
      nominee_name: "TestSpouse Customer",
      nominee_relationship: 'Spouse',
      nominee_age: 28,
      main_agent_commission_percentage: 30,
      commission_amount: 24000,
      active: true
    )

    puts "✅ Quick mobile API seed data created successfully!"
    puts ""
    puts "📊 Summary:"
    puts "- Created #{Customer.where(email: 'installment.test@example.com').count} test customer"
    puts "- Created #{FamilyMember.joins(:customer).where(customers: {email: 'installment.test@example.com'}).count} family members"
    puts "- Created #{HealthInsurance.where('policy_number LIKE ?', '%TEST%').count} health insurance policies"
    puts "- Created #{LifeInsurance.where('policy_number LIKE ?', '%TEST%').count} life insurance policies"
    puts ""
    puts "🎯 Test Scenarios Available:"
    puts "- Portfolio API: Customer has multiple active policies"
    puts "- Upcoming Installments API: Policies with installment dates in next 30 days"
    puts "- Upcoming Renewals API: Policies expiring in 15-45 days"
    puts "- Settings Profile API: Complete customer profile"
    puts ""
    puts "🧪 Test Customer Credentials:"
    puts "- Email: installment.test@example.com"
    puts "- Mobile: 9876543210"
    puts ""
    puts "🔥 Ready to test mobile APIs!"
  end
end