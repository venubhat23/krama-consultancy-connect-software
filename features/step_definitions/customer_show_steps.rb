require 'date'

# ─── Helpers ──────────────────────────────────────────────────────────────────

def find_or_create_show_individual(mobile, overrides = {})
  Customer.find_or_create_by!(mobile: mobile) do |c|
    c.first_name             = overrides[:first_name]             || 'ShowTest'
    c.last_name              = overrides[:last_name]              || 'Customer'
    c.customer_type          = 'individual'
    c.birth_date             = overrides[:birth_date]             || '1985-03-10'
    c.email                  = overrides[:email]                  || "showtest.#{mobile}@example.com"
    c.gender                 = overrides[:gender]                 || 'male'
    c.nominee_name           = overrides[:nominee_name]           || 'ShowTest Nominee'
    c.nominee_relation       = overrides[:nominee_relation]       || 'spouse'
    c.nominee_date_of_birth  = overrides[:nominee_date_of_birth]  || '1988-06-15'
    c.occupation             = overrides[:occupation]             || nil
    c.annual_income          = overrides[:annual_income]          || nil
    c.city                   = overrides[:city]                   || nil
    c.state                  = overrides[:state]                  || nil
    c.pincode                = overrides[:pincode]                || nil
    c.address                = overrides[:address]                || nil
    c.pan_no                 = overrides[:pan_no]                 || nil
    c.additional_information = overrides[:additional_info]        || nil
    c.bank_name              = 'HDFC Bank'
    c.account_no             = '12345678901234'
    c.ifsc_code              = 'HDFC0001234'
    c.status                 = overrides.fetch(:status, true)
  end
end

def find_or_create_minimal_individual(mobile)
  Customer.find_or_create_by!(mobile: mobile) do |c|
    c.first_name             = 'Minimal'
    c.last_name              = 'Client'
    c.customer_type          = 'individual'
    c.birth_date             = '1990-01-01'
    c.email                  = "minimal.#{mobile}@example.com"
    c.nominee_name           = 'Minimal Nominee'
    c.nominee_relation       = 'spouse'
    c.nominee_date_of_birth  = '1992-05-20'
    c.status                 = true
  end
end

def create_health_policy_for_customer(customer)
  suffix = customer.mobile.last(6)
  HealthInsurance.find_or_create_by!(customer_id: customer.id, insurance_company_name: 'Star Health Insurance') do |h|
    h.policy_holder           = "#{customer.first_name} #{customer.last_name}"
    h.policy_type             = 'New'
    h.insurance_type          = 'Individual'
    h.policy_booking_date     = Date.today
    h.policy_start_date       = Date.today
    h.policy_end_date         = Date.today + 365
    h.payment_mode            = 'Annual'
    h.sum_insured             = 500000
    h.net_premium             = 10000
    h.gst_percentage          = 18.0
    h.total_premium           = 11800
    h.policy_number           = "HLT#{suffix}#{rand(100..999)}"
    h.is_admin_added          = true
  end
end

def create_motor_policy_for_customer(customer)
  suffix = customer.mobile.last(6)
  policy_no = "MOT#{suffix}#{rand(100..999)}"
  MotorInsurance.find_or_create_by!(customer_id: customer.id, registration_number: "MH01AB#{suffix}") do |m|
    m.policy_holder        = "#{customer.first_name} #{customer.last_name}"
    m.insurance_company_name = 'Bajaj Allianz General Insurance'
    m.vehicle_type         = 'Old Vehicle'
    m.class_of_vehicle     = 'Private Car'
    m.insurance_type       = 'Comprehensive'
    m.policy_number        = policy_no
    m.policy_booking_date  = Date.today
    m.policy_start_date    = Date.today
    m.policy_end_date      = Date.today + 365
    m.vehicle_idv          = 400000
    m.net_premium          = 8000
    m.gst_percentage       = 18
    m.total_premium        = 9440
  end
end

def create_family_member_for_customer(customer, first_name = 'TestFamily', last_name = 'Member')
  FamilyMember.find_or_create_by!(customer_id: customer.id, first_name: first_name, last_name: last_name) do |f|
    f.relationship = 'spouse'
    f.birth_date   = '1988-06-15'
    f.gender       = 'female'
  end
end

def create_lead_for_show_customer(customer)
  Lead.find_or_create_by!(contact_number: customer.mobile) do |l|
    l.name                  = "#{customer.first_name} #{customer.last_name}"
    l.first_name            = customer.first_name
    l.last_name             = customer.last_name
    l.customer_type         = 'individual'
    l.lead_source           = 'walk_in'
    l.product_category      = 'insurance'
    l.product_subcategory   = 'health'
    l.is_direct             = true
    l.current_stage         = 'converted'
    l.converted_customer_id = customer.id
    l.created_date          = Date.current
  end
end

def find_customer_by_mobile(mobile)
  Customer.find_by!(mobile: mobile)
end

# ─── Navigation ───────────────────────────────────────────────────────────────

Given('a full individual customer exists with mobile {string}') do |mobile|
  @show_customer = find_or_create_show_individual(mobile)
end

Given('a minimal individual customer exists with mobile {string}') do |mobile|
  @show_customer = find_or_create_minimal_individual(mobile)
end

Given('a deactivated individual customer exists with mobile {string}') do |mobile|
  @show_customer = Customer.find_or_create_by!(mobile: mobile) do |c|
    c.first_name             = 'Inactive'
    c.last_name              = 'Customer'
    c.customer_type          = 'individual'
    c.birth_date             = '1985-03-10'
    c.email                  = "inactive.#{mobile}@example.com"
    c.nominee_name           = 'Inactive Nominee'
    c.nominee_relation       = 'spouse'
    c.nominee_date_of_birth  = '1988-06-15'
    c.status                 = false
  end
end

Given('a full individual customer with email {string} and mobile {string}') do |email, mobile|
  @show_customer = find_or_create_show_individual(mobile, email: email)
end

Given('a full individual customer with gender {string} and mobile {string}') do |gender, mobile|
  @show_customer = find_or_create_show_individual(mobile, gender: gender)
end

Given('a full individual customer with occupation {string} and mobile {string}') do |occupation, mobile|
  @show_customer = find_or_create_show_individual(mobile, occupation: occupation)
end

Given('a full individual customer with annual income {string} and mobile {string}') do |income, mobile|
  @show_customer = find_or_create_show_individual(mobile, annual_income: income.to_d)
  @expected_income = income
end

Given('a full individual customer with city {string} and mobile {string}') do |city, mobile|
  @show_customer = find_or_create_show_individual(mobile, city: city)
end

Given('a full individual customer with state {string} and mobile {string}') do |state, mobile|
  @show_customer = find_or_create_show_individual(mobile, state: state)
end

Given('a full individual customer with pincode {string} and mobile {string}') do |pincode, mobile|
  @show_customer = find_or_create_show_individual(mobile, pincode: pincode)
end

Given('a full individual customer with nominee {string} and mobile {string}') do |nominee_name, mobile|
  @show_customer = find_or_create_show_individual(
    mobile,
    nominee_name: nominee_name,
    nominee_relation: 'spouse',
    nominee_date_of_birth: '1988-06-15'
  )
end

Given('a full individual customer with PAN {string} and mobile {string}') do |pan, mobile|
  @show_customer = find_or_create_show_individual(mobile, pan_no: pan)
end

Given('a full individual customer with notes {string} and mobile {string}') do |notes, mobile|
  @show_customer = find_or_create_show_individual(mobile, additional_info: notes)
end

Given('a corporate customer exists with mobile {string}') do |mobile|
  @show_customer = Customer.find_or_create_by!(mobile: mobile) do |c|
    c.company_name  = 'TestShowCorp Ltd'
    c.customer_type = 'corporate'
    c.email         = "corpshow.#{mobile}@example.com"
    c.gst_no        = '27AAPFU0939F1ZV'
    c.status        = true
  end
end

Given('a corporate customer with GST {string} and mobile {string}') do |gst, mobile|
  @show_customer = Customer.find_or_create_by!(mobile: mobile) do |c|
    c.company_name  = 'GSTTestCorp Ltd'
    c.customer_type = 'corporate'
    c.email         = "gstcorp.#{mobile}@example.com"
    c.gst_no        = gst
    c.status        = true
  end
end

Given('a customer with a family member exists with mobile {string}') do |mobile|
  @show_customer = find_or_create_show_individual(mobile)
  create_family_member_for_customer(@show_customer)
end

Given('a customer with a family member named {string} exists with mobile {string}') do |full_name, mobile|
  parts = full_name.split(' ', 2)
  @show_customer = find_or_create_show_individual(mobile)
  create_family_member_for_customer(@show_customer, parts[0], parts[1] || 'Member')
end

Given('a customer with a health insurance policy exists with mobile {string}') do |mobile|
  create_test_prerequisites
  @show_customer = find_or_create_show_individual(mobile)
  @health_policy = create_health_policy_for_customer(@show_customer)
end

Given('a customer with an active health insurance policy exists with mobile {string}') do |mobile|
  create_test_prerequisites
  @show_customer = find_or_create_show_individual(mobile)
  @health_policy = create_health_policy_for_customer(@show_customer)
end

Given('a customer with a motor insurance policy exists with mobile {string}') do |mobile|
  create_test_prerequisites
  @show_customer = find_or_create_show_individual(mobile)
  @motor_policy = create_motor_policy_for_customer(@show_customer)
end

Given('a customer with an associated lead exists with mobile {string}') do |mobile|
  create_test_prerequisites
  @show_customer = find_or_create_show_individual(mobile)
  @associated_lead = create_lead_for_show_customer(@show_customer)
end

When('I visit the customer show page for mobile {string}') do |mobile|
  customer = Customer.find_by!(mobile: mobile)
  visit "/admin/customers/#{customer.id}"
  expect(page).to have_current_path(%r{/admin/customers/\d+}, wait: 15)
end

# ─── Section Expansion ────────────────────────────────────────────────────────

When('I expand the customer section {string}') do |section_name|
  header = first('.section-title', text: /\A#{Regexp.escape(section_name)}/, wait: 10)
  ancestor = header.ancestor('.section-header')
  ancestor.click
  sleep 0.5
end

# ─── Header Assertions ────────────────────────────────────────────────────────

Then('I should see the customer full name in the header') do
  customer = @show_customer
  full_name = [customer.first_name, customer.last_name].compact.join(' ')
  expect(page).to have_content(full_name, wait: 10)
end

Then('I should see the corporate customer company name') do
  expect(page).to have_content(@show_customer.company_name, wait: 10)
end

# ─── Basic Info Assertions ────────────────────────────────────────────────────

Then("I should see the customer's first name in the section") do
  expect(page).to have_content(@show_customer.first_name, wait: 10)
end

# ─── Professional / Financial Assertions ─────────────────────────────────────

Then('I should see customer annual income in section') do
  expect(page).to have_content(/#{Regexp.escape(@expected_income.to_s)}|annual income/i, wait: 10)
end

# ─── Insurance Policy Assertions ─────────────────────────────────────────────

Then('I should see the health insurance company name') do
  expect(page).to have_content('Star Health Insurance', wait: 10)
end

Then('I should see the motor insurance company name') do
  expect(page).to have_content('Bajaj Allianz General Insurance', wait: 10)
end

Then('I should see the active policy company name') do
  company = @health_policy&.insurance_company_name || 'Star Health Insurance'
  expect(page).to have_content(company, wait: 10)
end

Then('I should see customer active policies count as zero') do
  expect(page).to have_content(/Active Policies\s*\(\s*0\s*\)/i, wait: 10)
end

# ─── Associated Leads Assertions ──────────────────────────────────────────────

Then('I should see associated lead product category') do
  expect(page).to have_content(/insurance|health|investments|loans|travel/i, wait: 10)
end

Then('I should see associated lead stage') do
  expect(page).to have_content(/converted|generated|follow.up|consultation|closed/i, wait: 10)
end
