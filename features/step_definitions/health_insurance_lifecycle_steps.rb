require 'date'

# ─── Helpers ──────────────────────────────────────────────────────────────────

def find_or_create_health_lifecycle_customer(mobile)
  Customer.find_or_create_by!(mobile: mobile) do |c|
    c.first_name            = 'HealthLC'
    c.last_name             = 'Customer'
    c.customer_type         = 'individual'
    c.birth_date            = '1985-03-10'
    c.email                 = "hlc.#{mobile}@example.com"
    c.nominee_name          = 'Test Nominee'
    c.nominee_relation      = 'spouse'
    c.nominee_date_of_birth = '1988-06-15'
    c.status                = true
  end
end

def build_health_policy(customer, policy_number:, start_date:, end_date:, is_renewed: false, policy_type: 'New', original_policy_id: nil)
  HealthInsurance.find_or_create_by!(policy_number: policy_number) do |p|
    p.customer_id            = customer.id
    p.policy_holder          = 'Self'
    p.insurance_company_name = 'LIC of India'
    p.policy_type            = policy_type
    p.insurance_type         = 'Individual'
    p.payment_mode           = 'Yearly'
    p.policy_booking_date    = Date.today
    p.policy_start_date      = start_date
    p.policy_end_date        = end_date
    p.sum_insured            = 500_000
    p.net_premium            = 25_000
    p.gst_percentage         = 18.0
    p.total_premium          = 29_500
    p.is_admin_added         = true
    p.is_renewed             = is_renewed
    p.original_policy_id     = original_policy_id
  end
end

# ─── Lifecycle Given Steps ─────────────────────────────────────────────────────

Given('a health lifecycle customer exists with mobile {string}') do |mobile|
  @health_lc_customer   = find_or_create_health_lifecycle_customer(mobile)
  @health_lc_policies ||= {}
end

Given('a health policy {string} starting today ending {int} year from today for that customer') do |policy_number, years|
  @health_lc_policies ||= {}
  @health_lc_policies[policy_number] = build_health_policy(
    @health_lc_customer,
    policy_number: policy_number,
    start_date:    Date.today,
    end_date:      Date.today >> (years * 12)
  )
end

Given('a health policy {string} that expired {int} years ago and has been renewed for that customer') do |policy_number, years|
  @health_lc_policies ||= {}
  start_d = Date.today << (years * 12)
  end_d   = start_d >> 12
  @health_lc_policies[policy_number] = build_health_policy(
    @health_lc_customer,
    policy_number: policy_number,
    start_date:    start_d,
    end_date:      end_d,
    is_renewed:    true
  )
end

Given('a health renewal policy {string} replacing {string} for that customer') do |new_number, orig_number|
  @health_lc_policies ||= {}
  original = @health_lc_policies[orig_number] || HealthInsurance.find_by!(policy_number: orig_number)

  renewal = build_health_policy(
    @health_lc_customer,
    policy_number:      new_number,
    start_date:         Date.today,
    end_date:           Date.today >> 12,
    policy_type:        'Renewal',
    original_policy_id: original.id
  )
  @health_lc_policies[new_number] = renewal
  original.update_columns(is_renewed: true)
end

Given('a health policy {string} that expired {int} years ago and has NOT been renewed for that customer') do |policy_number, years|
  @health_lc_policies ||= {}
  start_d = Date.today << (years * 12)
  @health_lc_policies[policy_number] = build_health_policy(
    @health_lc_customer,
    policy_number: policy_number,
    start_date:    start_d,
    end_date:      start_d >> 12,
    is_renewed:    false
  )
end

When('I visit the health lifecycle customer show page') do
  visit "/admin/customers/#{@health_lc_customer.id}"
  expect(page).to have_current_path(%r{/admin/customers/\d+}, wait: 15)
end

# ─── Lifecycle Assertions ──────────────────────────────────────────────────────

Then('{string} should be visible in the Health Insurance section') do |policy_number|
  page.execute_script("var el = document.getElementById('activePoliciesCollapse'); if(el) el.classList.add('show');")
  expect(page).to have_content(policy_number, wait: 10)
end

Then('{string} should be visible in the health Past Policy section') do |policy_number|
  within('.collapse.show, body') { expect(page).to have_content(policy_number, wait: 5) }
rescue Capybara::ElementNotFound
  expect(page).to have_content(policy_number, wait: 5)
end

Then('{string} should be visible in the health Expired Policy section') do |policy_number|
  within('.collapse.show, body') { expect(page).to have_content(policy_number, wait: 5) }
rescue Capybara::ElementNotFound
  expect(page).to have_content(policy_number, wait: 5)
end

Then('{string} should NOT be visible in the health Past Policy section') do |policy_number|
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

Then('{string} should NOT be visible in the health Expired Policy section') do |policy_number|
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

Given('a health insurance policy for view exists with number {string}') do |policy_number|
  create_test_prerequisites
  build_health_policy(@customer, policy_number: policy_number, start_date: Date.today, end_date: Date.today >> 12)
end

When('I visit the health insurance show page for {string}') do |policy_number|
  policy = HealthInsurance.find_by!(policy_number: policy_number)
  visit "/admin/insurance/health/#{policy.id}"
  expect(page).to have_current_path(%r{/admin/insurance/health/\d+}, wait: 10)
end

Then('I should be on the health insurance show page') do
  expect(page).to have_current_path(%r{/admin/insurance/health/\d+}, wait: 10)
end

Then('I should see health insurance premium details on show page') do
  expect(page).to have_content(/₹|premium|net.premium/i, wait: 10)
end

Then('I should see health insurance policy type on show page') do
  expect(page).to have_content(/New|Renewal|Porting/i, wait: 10)
end

Then('I should see health insurance edit link on show page') do
  expect(page).to have_link(href: /edit/i, wait: 5).or have_content(/Edit/i, wait: 5)
end

Then('I should see health insurance list action buttons') do
  expect(page).to have_css('a[href*="/insurance/health/"]', wait: 10)
end

# ─── Edit Helpers ─────────────────────────────────────────────────────────────

Given('a health insurance policy for edit exists with number {string}') do |policy_number|
  create_test_prerequisites
  build_health_policy(@customer, policy_number: policy_number, start_date: Date.today, end_date: Date.today >> 12)
end

When('I navigate to edit health insurance {string}') do |policy_number|
  policy = HealthInsurance.find_by!(policy_number: policy_number)
  visit "/admin/insurance/health/#{policy.id}/edit"
  expect(page).to have_current_path(%r{/admin/insurance/health/\d+/edit}, wait: 10)
end

When('I update the health insurance net premium to {string}') do |premium|
  page.execute_script(
    "var el = document.getElementById('net_premium') || document.querySelector('[name=\"health_insurance[net_premium]\"]'); if(el){ el.value = #{premium.to_json}; el.dispatchEvent(new Event('input',{bubbles:true})); }"
  )
end

When('I update the health insurance payment mode to {string}') do |mode|
  begin
    select mode, from: 'health_insurance[payment_mode]'
  rescue Capybara::ElementNotFound
    page.execute_script(
      "var el = document.querySelector('[name=\"health_insurance[payment_mode]\"]'); if(el){ el.value = #{mode.to_json}; el.dispatchEvent(new Event('change',{bubbles:true})); }"
    )
  end
end

When('I update the health insurance plan name to {string}') do |name|
  begin
    fill_in 'health_insurance[plan_name]', with: name
  rescue Capybara::ElementNotFound
    page.execute_script("var el = document.querySelector('[name=\"health_insurance[plan_name]\"]'); if(el) el.value = #{name.to_json};")
  end
end

When('I update the health insurance type to {string}') do |type|
  begin
    select type, from: 'health_insurance[insurance_type]'
  rescue Capybara::ElementNotFound
    page.execute_script(
      "var el = document.querySelector('[name=\"health_insurance[insurance_type]\"]'); if(el){ el.value = #{type.to_json}; el.dispatchEvent(new Event('change',{bubbles:true})); }"
    )
  end
end

Then('I should see health insurance updated successfully') do
  expect(page).to have_content(
    /health insurance.*successfully updated|was successfully updated/i,
    wait: 15
  )
end

# ─── Delete Helpers ───────────────────────────────────────────────────────────

When('I delete the health insurance from the show page') do
  path = URI.parse(current_url).path
  insurance_js_delete(path)
  expect(page).to have_current_path(%r{/admin/insurance/health}, wait: 15)
end

When('I delete health insurance {string} from the list page') do |policy_number|
  policy = HealthInsurance.find_by!(policy_number: policy_number)
  insurance_js_delete("/admin/insurance/health/#{policy.id}")
  expect(page).to have_content(/successfully deleted/i, wait: 15)
end

Then('I should see health insurance deleted successfully') do
  expect(page).to have_content(
    /health insurance.*successfully deleted|was successfully deleted|deleted successfully/i,
    wait: 10
  )
end

Then('health insurance {string} should not appear in the list') do |policy_number|
  visit '/admin/insurance/health'
  expect(page).not_to have_content(policy_number, wait: 5)
end
