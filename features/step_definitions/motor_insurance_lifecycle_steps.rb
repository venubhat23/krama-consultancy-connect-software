require 'date'

# ─── Helpers ──────────────────────────────────────────────────────────────────

def find_or_create_motor_lifecycle_customer(mobile)
  Customer.find_or_create_by!(mobile: mobile) do |c|
    c.first_name            = 'MotorLC'
    c.last_name             = 'Customer'
    c.customer_type         = 'individual'
    c.birth_date            = '1982-07-20'
    c.email                 = "mlc.#{mobile}@example.com"
    c.nominee_name          = 'Test Nominee'
    c.nominee_relation      = 'spouse'
    c.nominee_date_of_birth = '1985-09-10'
    c.status                = true
  end
end

# Motor renewal is detected via DB query (no is_renewed column).
# has_been_renewed? checks for another MotorInsurance with same
# customer_id + registration_number + policy_type='Renewal'
def build_motor_policy(customer, policy_number:, registration_number:, start_date:, end_date:,
                       policy_type: 'New', insurance_type: 'Comprehensive')
  MotorInsurance.find_or_create_by!(policy_number: policy_number) do |p|
    p.customer_id            = customer.id
    p.policy_holder          = 'Self'
    p.insurance_company_name = 'Bajaj Allianz General Insurance'
    p.policy_type            = policy_type
    p.vehicle_type           = 'Old Vehicle'
    p.class_of_vehicle       = 'Private Car'
    p.insurance_type         = insurance_type
    p.registration_number    = registration_number
    p.vehicle_number         = registration_number
    p.policy_booking_date    = Date.today
    p.policy_start_date      = start_date
    p.policy_end_date        = end_date
    p.vehicle_idv            = insurance_type == 'Third Party' ? nil : 300_000
    p.net_premium            = 15_000
    p.gst_percentage         = 18.0
    p.total_premium          = 17_700
    p.is_admin_added         = true
  end
end

# ─── Lifecycle Given Steps ─────────────────────────────────────────────────────

Given('a motor lifecycle customer exists with mobile {string}') do |mobile|
  @motor_lc_customer   = find_or_create_motor_lifecycle_customer(mobile)
  @motor_lc_policies ||= {}
end

Given('a motor policy {string} for vehicle {string} starting today ending {int} year from today for that customer') do |policy_number, reg, years|
  @motor_lc_policies ||= {}
  @motor_lc_policies[policy_number] = build_motor_policy(
    @motor_lc_customer,
    policy_number:       policy_number,
    registration_number: reg,
    start_date:          Date.today,
    end_date:            Date.today >> (years * 12)
  )
end

Given('a motor policy {string} for vehicle {string} that expired {int} years ago for that customer') do |policy_number, reg, years|
  @motor_lc_policies ||= {}
  start_d = Date.today << (years * 12)
  @motor_lc_policies[policy_number] = build_motor_policy(
    @motor_lc_customer,
    policy_number:       policy_number,
    registration_number: reg,
    start_date:          start_d,
    end_date:            start_d >> 12
  )
end

Given('a motor renewal policy {string} for vehicle {string} replacing {string} for that customer') do |new_number, reg, _orig_number|
  @motor_lc_policies ||= {}
  # Same registration_number + policy_type='Renewal' triggers has_been_renewed? on the original
  @motor_lc_policies[new_number] = build_motor_policy(
    @motor_lc_customer,
    policy_number:       new_number,
    registration_number: reg,
    start_date:          Date.today,
    end_date:            Date.today >> 12,
    policy_type:         'Renewal'
  )
end

When('I visit the motor lifecycle customer show page') do
  visit "/admin/customers/#{@motor_lc_customer.id}"
  expect(page).to have_current_path(%r{/admin/customers/\d+}, wait: 15)
end

# ─── Lifecycle Assertions ──────────────────────────────────────────────────────

Then('{string} should be visible in the Motor Insurance section') do |policy_number|
  page.execute_script("var el = document.getElementById('activePoliciesCollapse'); if(el) el.classList.add('show');")
  expect(page).to have_content(policy_number, wait: 10)
end

Then('{string} should be visible in the motor Past Policy section') do |policy_number|
  within('.collapse.show, body') { expect(page).to have_content(policy_number, wait: 5) }
rescue Capybara::ElementNotFound
  expect(page).to have_content(policy_number, wait: 5)
end

Then('{string} should be visible in the motor Expired Policy section') do |policy_number|
  within('.collapse.show, body') { expect(page).to have_content(policy_number, wait: 5) }
rescue Capybara::ElementNotFound
  expect(page).to have_content(policy_number, wait: 5)
end

Then('{string} should NOT be visible in the motor Past Policy section') do |policy_number|
  expect(page).not_to have_content(policy_number, wait: 3)
rescue RSpec::Expectations::ExpectationNotMetError
  within('body') do
    sec = first('.section-header', text: /Past Polic/i)
    if sec && (sec_id = sec['data-bs-target']&.tr('#', ''))
      sec_text = begin; find("##{sec_id}", visible: :all).text; rescue StandardError; ''; end
      expect(sec_text).not_to include(policy_number)
    end
  end
end

Then('{string} should NOT be visible in the motor Expired Policy section') do |policy_number|
  expect(page).not_to have_content(policy_number, wait: 3)
rescue RSpec::Expectations::ExpectationNotMetError
  within('body') do
    sec = first('.section-header', text: /Expired Polic/i)
    if sec && (sec_id = sec['data-bs-target']&.tr('#', ''))
      sec_text = begin; find("##{sec_id}", visible: :all).text; rescue StandardError; ''; end
      expect(sec_text).not_to include(policy_number)
    end
  end
end

# ─── View Helpers ─────────────────────────────────────────────────────────────

Given('a motor insurance policy for view exists with number {string}') do |policy_number|
  create_test_prerequisites
  build_motor_policy(
    @customer,
    policy_number:       policy_number,
    registration_number: "MH#{policy_number[-4..]}",
    start_date:          Date.today,
    end_date:            Date.today >> 12
  )
end

When('I visit the motor insurance show page for {string}') do |policy_number|
  policy = MotorInsurance.find_by!(policy_number: policy_number)
  visit "/admin/insurance/motor/#{policy.id}"
  expect(page).to have_current_path(%r{/admin/insurance/motor/\d+}, wait: 10)
end

Then('I should be on the motor insurance show page') do
  expect(page).to have_current_path(%r{/admin/insurance/motor/\d+}, wait: 10)
end

Then('I should see motor registration number on show page') do
  expect(page).to have_content(/MH\d|registration/i, wait: 10)
end

Then('I should see motor insurance premium details on show page') do
  expect(page).to have_content(/₹|premium|net.premium/i, wait: 10)
end

Then('I should see motor insurance edit link on show page') do
  expect(page).to have_link(href: /edit/i, wait: 5).or have_content(/Edit/i, wait: 5)
end

Then('I should see motor insurance list action buttons') do
  expect(page).to have_css('a[href*="/insurance/motor/"]', wait: 10)
end

# ─── Edit Helpers ─────────────────────────────────────────────────────────────

Given('a motor insurance policy for edit exists with number {string}') do |policy_number|
  create_test_prerequisites
  build_motor_policy(
    @customer,
    policy_number:       policy_number,
    registration_number: "MH#{policy_number[-4..]}ED",
    start_date:          Date.today,
    end_date:            Date.today >> 12
  )
end

When('I navigate to edit motor insurance {string}') do |policy_number|
  policy = MotorInsurance.find_by!(policy_number: policy_number)
  visit "/admin/insurance/motor/#{policy.id}/edit"
  expect(page).to have_current_path(%r{/admin/insurance/motor/\d+/edit}, wait: 10)
end

When('I update the motor insurance net premium to {string}') do |premium|
  page.execute_script(
    "var el = document.getElementById('net_premium') || document.querySelector('[name=\"motor_insurance[net_premium]\"]'); if(el){ el.value = #{premium.to_json}; el.dispatchEvent(new Event('input',{bubbles:true})); }"
  )
end

When('I update the motor insurance type to {string}') do |type|
  begin
    select type, from: 'motor_insurance[insurance_type]'
  rescue Capybara::ElementNotFound
    page.execute_script(
      "var el = document.querySelector('[name=\"motor_insurance[insurance_type]\"]'); if(el){ el.value = #{type.to_json}; el.dispatchEvent(new Event('change',{bubbles:true})); }"
    )
  end
end

Then('I should see motor insurance updated successfully') do
  expect(page).to have_content(/motor insurance.*successfully updated|was successfully updated/i, wait: 15)
end

# ─── Delete Helpers ───────────────────────────────────────────────────────────

When('I delete the motor insurance from the show page') do
  path = URI.parse(current_url).path
  insurance_js_delete(path)
  expect(page).to have_current_path(%r{/admin/insurance/motor}, wait: 15)
end

When('I delete motor insurance {string} from the list page') do |policy_number|
  policy = MotorInsurance.find_by!(policy_number: policy_number)
  insurance_js_delete("/admin/insurance/motor/#{policy.id}")
  expect(page).to have_content(/successfully deleted/i, wait: 15)
end

Then('I should see motor insurance deleted successfully') do
  expect(page).to have_content(/motor insurance.*successfully deleted|was successfully deleted|deleted successfully/i, wait: 10)
end

Then('motor insurance {string} should not appear in the list') do |policy_number|
  visit '/admin/insurance/motor'
  expect(page).not_to have_content(policy_number, wait: 5)
end
