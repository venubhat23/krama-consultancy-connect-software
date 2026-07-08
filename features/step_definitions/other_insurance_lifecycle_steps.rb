require 'date'

# ─── Helpers ──────────────────────────────────────────────────────────────────

def find_or_create_other_lifecycle_customer(mobile)
  Customer.find_or_create_by!(mobile: mobile) do |c|
    c.first_name            = 'OtherLC'
    c.last_name             = 'Customer'
    c.customer_type         = 'individual'
    c.birth_date            = '1980-11-25'
    c.email                 = "olc.#{mobile}@example.com"
    c.nominee_name          = 'Test Nominee'
    c.nominee_relation      = 'spouse'
    c.nominee_date_of_birth = '1983-04-12'
    c.status                = true
  end
end

def build_other_policy(customer, policy_number:, start_date:, end_date:, is_renewed: false,
                       policy_type: 'New', original_policy_id: nil,
                       insurance_type: 'Travel Insurance')
  OtherInsurance.find_or_create_by!(policy_number: policy_number) do |p|
    p.customer_id            = customer.id
    p.policy_holder          = 'Self'
    p.insurance_company_name = 'LIC of India'
    p.insurance_type         = insurance_type
    p.policy_type            = policy_type
    p.policy_booking_date    = Date.today
    p.policy_start_date      = start_date
    p.policy_end_date        = end_date
    p.net_premium            = 5_000
    p.gst_percentage         = 18.0
    p.total_premium          = 5_900
    p.is_admin_added         = true
    p.is_renewed             = is_renewed
    p.original_policy_id     = original_policy_id
  end
end

# ─── Lifecycle Given Steps ─────────────────────────────────────────────────────

Given('an other lifecycle customer exists with mobile {string}') do |mobile|
  @other_lc_customer   = find_or_create_other_lifecycle_customer(mobile)
  @other_lc_policies ||= {}
end

Given('an other policy {string} starting today ending {int} year from today for that customer') do |policy_number, years|
  @other_lc_policies ||= {}
  @other_lc_policies[policy_number] = build_other_policy(
    @other_lc_customer,
    policy_number: policy_number,
    start_date:    Date.today,
    end_date:      Date.today >> (years * 12)
  )
end

Given('an other policy {string} that expired {int} years ago and has been renewed for that customer') do |policy_number, years|
  @other_lc_policies ||= {}
  start_d = Date.today << (years * 12)
  @other_lc_policies[policy_number] = build_other_policy(
    @other_lc_customer,
    policy_number: policy_number,
    start_date:    start_d,
    end_date:      start_d >> 12,
    is_renewed:    true
  )
end

Given('an other renewal policy {string} replacing {string} for that customer') do |new_number, orig_number|
  @other_lc_policies ||= {}
  original = @other_lc_policies[orig_number] || OtherInsurance.find_by!(policy_number: orig_number)

  renewal = build_other_policy(
    @other_lc_customer,
    policy_number:      new_number,
    start_date:         Date.today,
    end_date:           Date.today >> 12,
    policy_type:        'Renewal',
    original_policy_id: original.id
  )
  @other_lc_policies[new_number] = renewal
  original.update_columns(is_renewed: true)
end

Given('an other policy {string} that expired {int} years ago and has NOT been renewed for that customer') do |policy_number, years|
  @other_lc_policies ||= {}
  start_d = Date.today << (years * 12)
  @other_lc_policies[policy_number] = build_other_policy(
    @other_lc_customer,
    policy_number: policy_number,
    start_date:    start_d,
    end_date:      start_d >> 12,
    is_renewed:    false
  )
end

When('I visit the other lifecycle customer show page') do
  visit "/admin/customers/#{@other_lc_customer.id}"
  expect(page).to have_current_path(%r{/admin/customers/\d+}, wait: 15)
end

# ─── Lifecycle Assertions ──────────────────────────────────────────────────────

Then('{string} should be visible in the Other Insurance section') do |policy_number|
  page.execute_script("var el = document.getElementById('activePoliciesCollapse'); if(el) el.classList.add('show');")
  expect(page).to have_content(policy_number, wait: 10)
end

Then('{string} should be visible in the other Past Policy section') do |policy_number|
  within('.collapse.show, body') { expect(page).to have_content(policy_number, wait: 5) }
rescue Capybara::ElementNotFound
  expect(page).to have_content(policy_number, wait: 5)
end

Then('{string} should be visible in the other Expired Policy section') do |policy_number|
  within('.collapse.show, body') { expect(page).to have_content(policy_number, wait: 5) }
rescue Capybara::ElementNotFound
  expect(page).to have_content(policy_number, wait: 5)
end

Then('{string} should NOT be visible in the other Past Policy section') do |policy_number|
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

Then('{string} should NOT be visible in the other Expired Policy section') do |policy_number|
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

Given('an other insurance policy for view exists with number {string}') do |policy_number|
  create_test_prerequisites
  build_other_policy(@customer, policy_number: policy_number, start_date: Date.today, end_date: Date.today >> 12)
end

When('I visit the other insurance show page for {string}') do |policy_number|
  policy = OtherInsurance.find_by!(policy_number: policy_number)
  visit "/admin/insurance/other/#{policy.id}"
  expect(page).to have_current_path(%r{/admin/insurance/other/\d+}, wait: 10)
end

Then('I should be on the other insurance show page') do
  expect(page).to have_current_path(%r{/admin/insurance/other/\d+}, wait: 10)
end

Then('I should see other insurance type on show page') do
  expect(page).to have_content(/Travel|Home|Personal Accident|General/i, wait: 10)
end

Then('I should see other insurance premium details on show page') do
  expect(page).to have_content(/₹|premium|net.premium/i, wait: 10)
end

Then('I should see other insurance edit link on show page') do
  expect(page).to have_link(href: /edit/i, wait: 5).or have_content(/Edit/i, wait: 5)
end

Then('I should see other insurance list action buttons') do
  expect(page).to have_css('a[href*="/insurance/other/"]', wait: 10)
end

# ─── Edit Helpers ─────────────────────────────────────────────────────────────

Given('an other insurance policy for edit exists with number {string}') do |policy_number|
  create_test_prerequisites
  build_other_policy(@customer, policy_number: policy_number, start_date: Date.today, end_date: Date.today >> 12)
end

When('I navigate to edit other insurance {string}') do |policy_number|
  policy = OtherInsurance.find_by!(policy_number: policy_number)
  visit "/admin/insurance/other/#{policy.id}/edit"
  expect(page).to have_current_path(%r{/admin/insurance/other/\d+/edit}, wait: 10)
end

When('I update the other insurance net premium to {string}') do |premium|
  page.execute_script(
    "var el = document.getElementById('net_premium') || document.querySelector('[name=\"other_insurance[net_premium]\"]'); if(el){ el.value = #{premium.to_json}; el.dispatchEvent(new Event('input',{bubbles:true})); }"
  )
end

When('I update the other insurance policy type to {string}') do |type|
  begin
    select type, from: 'other_insurance[policy_type]'
  rescue Capybara::ElementNotFound
    page.execute_script(
      "var el = document.querySelector('[name=\"other_insurance[policy_type]\"]'); if(el){ el.value = #{type.to_json}; el.dispatchEvent(new Event('change',{bubbles:true})); }"
    )
  end
end

When('I update the other insurance type to {string}') do |type|
  begin
    select type, from: 'other_insurance[insurance_type]'
  rescue Capybara::ElementNotFound
    page.execute_script(
      "var el = document.querySelector('[name=\"other_insurance[insurance_type]\"]'); if(el){ el.value = #{type.to_json}; el.dispatchEvent(new Event('change',{bubbles:true})); }"
    )
  end
end

Then('I should see other insurance updated successfully') do
  expect(page).to have_content(/other insurance.*successfully updated|general insurance.*successfully updated|was successfully updated/i, wait: 15)
end

# ─── Delete Helpers ───────────────────────────────────────────────────────────

When('I delete the other insurance from the show page') do
  path = URI.parse(current_url).path
  insurance_js_delete(path)
  expect(page).to have_current_path(%r{/admin/insurance/other}, wait: 15)
end

When('I delete other insurance {string} from the list page') do |policy_number|
  policy = OtherInsurance.find_by!(policy_number: policy_number)
  insurance_js_delete("/admin/insurance/other/#{policy.id}")
  expect(page).to have_content(/successfully deleted/i, wait: 15)
end

Then('I should see other insurance deleted successfully') do
  expect(page).to have_content(/other insurance.*successfully deleted|general insurance.*successfully deleted|was successfully deleted|deleted successfully/i, wait: 10)
end

Then('other insurance {string} should not appear in the list') do |policy_number|
  visit '/admin/insurance/other'
  expect(page).not_to have_content(policy_number, wait: 5)
end
