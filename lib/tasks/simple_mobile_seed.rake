namespace :mobile_api do
  desc 'Simple seed data for mobile APIs with upcoming installments'
  task simple_seed: :environment do
    puts "🚀 Starting simple mobile API seed data creation..."

    # Create or find test customer for upcoming installments
    puts "👤 Creating test customer..."
    test_customer = Customer.find_or_create_by(email: "installment.test@example.com") do |c|
      c.customer_type = 'individual'
      c.first_name = "TestInstallment"
      c.last_name = "Customer"
      c.mobile = "9999999999"
      c.address = "Test Address, Mumbai"
      c.state = "Maharashtra"
      c.city = "Mumbai"
      c.pincode = "400001"
      c.birth_date = 30.years.ago
      c.age = 30
      c.gender = 'male'
      c.education = 'Graduate'
      c.marital_status = 'married'
      c.occupation = 'Service'
      c.annual_income = 600000
      c.pan_number = "TESTPN123F"
      c.status = true
      c.added_by = "admin"
    end

    puts "Customer created: #{test_customer.display_name} (ID: #{test_customer.id})"

    # Create Health Insurance with upcoming monthly installments
    puts "🏥 Creating Health Insurance with upcoming installments..."

    policy_number = "HLT_MONTHLY_#{Time.current.strftime('%Y%m%d%H%M%S')}"
    health_policy = HealthInsurance.create!(
      customer: test_customer,
      policy_holder: test_customer.display_name,
      insurance_company_name: "Star Health Allied Insurance Co Ltd",
      plan_name: "Family Health Protection Plan",
      policy_number: policy_number,
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
      # Key field for upcoming installments - due in 5 days
      installment_autopay_start_date: 5.days.from_now,
      installment_autopay_end_date: 6.months.from_now
    )

    puts "Health policy created: #{health_policy.policy_number}"

    # Create Life Insurance with upcoming installments
    puts "👨‍👩‍👧‍👦 Creating Life Insurance with upcoming installments..."

    life_policy_number = "LIF_MONTHLY_#{Time.current.strftime('%Y%m%d%H%M%S')}"
    life_policy = LifeInsurance.create!(
      customer: test_customer,
      policy_holder: test_customer.display_name,
      insured_name: test_customer.display_name,
      insurance_company_name: "ICICI Prudential Life Insurance Co Ltd",
      plan_name: "Term Life Protection Plan",
      policy_number: life_policy_number,
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
      # Key field for upcoming installments - due in 2 days
      installment_autopay_start_date: 2.days.from_now,
      installment_autopay_end_date: 14.years.from_now,
      active: true
    )

    puts "Life policy created: #{life_policy.policy_number}"

    # Create policy for upcoming renewals
    puts "🔄 Creating policy for upcoming renewals..."

    expiring_policy_number = "HLT_EXPIRING_#{Time.current.strftime('%Y%m%d%H%M%S')}"
    expiring_policy = HealthInsurance.create!(
      customer: test_customer,
      policy_holder: test_customer.display_name,
      insurance_company_name: "Care Health Insurance Ltd",
      plan_name: "Health Plan Expiring Soon",
      policy_number: expiring_policy_number,
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

    puts "Expiring policy created: #{expiring_policy.policy_number}"

    # Create active policy for portfolio
    puts "📋 Creating active policy for portfolio..."

    active_policy_number = "HLT_ACTIVE_#{Time.current.strftime('%Y%m%d%H%M%S')}"
    active_policy = HealthInsurance.create!(
      customer: test_customer,
      policy_holder: test_customer.display_name,
      insurance_company_name: "Niva Bupa Health Insurance Co Ltd",
      plan_name: "Active Family Health Plan",
      policy_number: active_policy_number,
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

    puts "Active policy created: #{active_policy.policy_number}"

    puts "✅ Simple mobile API seed data created successfully!"
    puts ""
    puts "📊 Summary:"
    puts "- Test Customer: #{test_customer.display_name} (#{test_customer.email})"
    puts "- Health policies: #{HealthInsurance.where(customer: test_customer).count}"
    puts "- Life policies: #{LifeInsurance.where(customer: test_customer).count}"
    puts ""
    puts "🎯 Test Scenarios Available:"
    puts "- Portfolio API: Customer has multiple active policies"
    puts "- Upcoming Installments API: 2 policies with installment dates in next 5 days"
    puts "- Upcoming Renewals API: 1 policy expiring in 15 days"
    puts "- Settings Profile API: Complete customer profile"
    puts ""
    puts "🧪 Test Customer Credentials:"
    puts "- Email: installment.test@example.com"
    puts "- Mobile: 9999999999"
    puts ""
    puts "🔥 Ready to test mobile APIs!"

    # Test the upcoming installments API data
    puts ""
    puts "🧪 Testing upcoming installments data..."
    customer = Customer.find_by(email: "installment.test@example.com")
    health_policies = HealthInsurance.where(customer: customer).active
    life_policies = LifeInsurance.where(customer: customer).active

    installments_count = 0

    health_policies.each do |policy|
      if policy.installment_autopay_start_date.present? && policy.installment_autopay_start_date <= 30.days.from_now
        installments_count += 1
        puts "- Health Policy #{policy.policy_number}: Next installment #{policy.installment_autopay_start_date}"
      end
    end

    life_policies.each do |policy|
      if policy.installment_autopay_start_date.present? && policy.installment_autopay_start_date <= 30.days.from_now
        installments_count += 1
        puts "- Life Policy #{policy.policy_number}: Next installment #{policy.installment_autopay_start_date}"
      end
    end

    puts "Total upcoming installments: #{installments_count}"
  end
end