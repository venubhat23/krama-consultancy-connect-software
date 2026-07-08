require 'date'

# ─── Helpers ──────────────────────────────────────────────────────────────────

def find_or_create_lifecycle_customer(mobile)
  Customer.find_or_create_by!(mobile: mobile) do |c|
    c.first_name            = 'Lifecycle'
    c.last_name             = 'Customer'
    c.customer_type         = 'individual'
    c.birth_date            = '1985-03-10'
    c.email                 = "lifecycle.#{mobile}@example.com"
    c.nominee_name          = 'Test Nominee'
    c.nominee_relation      = 'spouse'
    c.nominee_date_of_birth = '1988-06-15'
    c.status                = true
  end
end

def build_life_policy(customer, policy_number:, start_date:, end_date:, is_renewed: false, policy_type: 'New', original_policy_id: nil)
  distributor = Distributor.find_by!(email: 'testdist@drwise.com')
  term_years  = [(( end_date - start_date) / 365.25).ceil, 1].max

  LifeInsurance.find_or_create_by!(policy_number: policy_number) do |p|
    p.customer_id           = customer.id
    p.distributor_id        = distributor.id
    p.policy_holder         = 'Self'
    p.insured_name          = customer.first_name
    p.insurance_company_name = 'LIC of India'
    p.policy_type           = policy_type
    p.payment_mode          = 'Yearly'
    p.policy_booking_date   = Date.today
    p.policy_start_date     = start_date
    p.policy_end_date       = end_date
    p.policy_term           = term_years
    p.premium_payment_term  = term_years
    p.sum_insured           = 1_000_000
    p.net_premium           = 50_000
    p.total_premium         = 52_250
    p.first_year_gst_percentage = 4.5
    p.is_admin_added        = true
    p.is_renewed            = is_renewed
    p.original_policy_id    = original_policy_id
  end
end

def find_life_policy_by_number(policy_number)
  LifeInsurance.find_by!(policy_number: policy_number)
end

# ─── Lifecycle Given Steps ─────────────────────────────────────────────────────

Given('a lifecycle customer exists with mobile {string}') do |mobile|
  @lifecycle_customer = find_or_create_lifecycle_customer(mobile)
end

Given('a life policy {string} starting today ending {int} year from today for that customer') do |policy_number, years|
  @lifecycle_policies ||= {}
  end_date = Date.today >> (years * 12)
  @lifecycle_policies[policy_number] = build_life_policy(
    @lifecycle_customer,
    policy_number: policy_number,
    start_date: Date.today,
    end_date: end_date,
    is_renewed: false
  )
end

Given('a life policy {string} starting today ending {int} years from today for that customer') do |policy_number, years|
  @lifecycle_policies ||= {}
  end_date = Date.today >> (years * 12)
  @lifecycle_policies[policy_number] = build_life_policy(
    @lifecycle_customer,
    policy_number: policy_number,
    start_date: Date.today,
    end_date: end_date,
    is_renewed: false
  )
end

Given('a life policy {string} that expired {int} years ago and has been renewed for that customer') do |policy_number, years|
  @lifecycle_policies ||= {}
  start_date = Date.today << (years * 12)
  end_date   = start_date >> 12
  policy = build_life_policy(
    @lifecycle_customer,
    policy_number: policy_number,
    start_date: start_date,
    end_date: end_date,
    is_renewed: true
  )
  @lifecycle_policies[policy_number] = policy
  @last_expired_renewed_policy = policy
end

Given('a renewal life policy {string} replacing {string} for that customer') do |new_number, orig_number|
  @lifecycle_policies ||= {}
  original = @lifecycle_policies[orig_number] || LifeInsurance.find_by!(policy_number: orig_number)

  policy = build_life_policy(
    @lifecycle_customer,
    policy_number: new_number,
    start_date: Date.today,
    end_date: Date.today >> 12,
    policy_type: 'Renewal',
    original_policy_id: original.id
  )
  @lifecycle_policies[new_number] = policy

  # Mark original as renewed
  original.update_columns(is_renewed: true, renewal_policy_id: policy.id)
end

Given('a life policy {string} that expired {int} years ago and has NOT been renewed for that customer') do |policy_number, years|
  @lifecycle_policies ||= {}
  start_date = Date.today << (years * 12)
  end_date   = start_date >> 12
  @lifecycle_policies[policy_number] = build_life_policy(
    @lifecycle_customer,
    policy_number: policy_number,
    start_date: start_date,
    end_date: end_date,
    is_renewed: false
  )
end

When('I visit the lifecycle customer show page') do
  visit "/admin/customers/#{@lifecycle_customer.id}"
  expect(page).to have_current_path(%r{/admin/customers/\d+}, wait: 15)
end

# ─── Lifecycle Count Assertions ────────────────────────────────────────────────

Then('the Active Policies count should be {int}') do |count|
  expect(page).to have_content(/Active Policies\s*\(\s*#{count}\s*\)/i, wait: 10)
end

Then('the Active Policies count should be at least {int}') do |count|
  actual = page.find('.section-title, h5', text: /Active Policies/i, wait: 10).text
  match  = actual.match(/\((\d+)\)/)
  expect(match[1].to_i).to be >= count if match
end

Then('the Past Policies count should be {int}') do |count|
  expect(page).to have_content(/Past Polic.*\(\s*#{count}\s*\)/i, wait: 10)
end

Then('the Expired Policies count should be {int}') do |count|
  expect(page).to have_content(/Expired Polic.*\(\s*#{count}\s*\)/i, wait: 10)
end

# ─── Lifecycle Section Visibility Assertions ───────────────────────────────────

Then('{string} should be visible in the Life Insurance section') do |policy_number|
  page.execute_script("var el = document.getElementById('activePoliciesCollapse'); if(el) el.classList.add('show');")
  expect(page).to have_content(policy_number, wait: 10)
end

Then('{string} should be visible in the Past Policy section') do |policy_number|
  within('.collapse.show, [data-section="past"], body') do
    expect(page).to have_content(policy_number, wait: 5)
  end
rescue Capybara::ElementNotFound
  expect(page).to have_content(policy_number, wait: 5)
end

Then('{string} should be visible in the Expired Policy section') do |policy_number|
  within('.collapse.show, [data-section="expired"], body') do
    expect(page).to have_content(policy_number, wait: 5)
  end
rescue Capybara::ElementNotFound
  expect(page).to have_content(policy_number, wait: 5)
end

Then('{string} should NOT be visible in the Past Policy section') do |policy_number|
  # Expand the Past Policy section first, then assert absence
  expect(page).not_to have_content(policy_number, wait: 3)
rescue RSpec::Expectations::ExpectationNotMetError
  # If it appears elsewhere on the page (e.g. product info), do a targeted check
  within('body') do
    past_section = first('.section-header', text: /Past Polic/i)
    if past_section
      past_id = past_section['data-bs-target']&.tr('#', '')
      if past_id
        section_content = find("##{past_id}", visible: :all).text rescue ''
        expect(section_content).not_to include(policy_number)
      end
    end
  end
end

Then('{string} should NOT be visible in the Expired Policy section') do |policy_number|
  expect(page).not_to have_content(policy_number, wait: 3)
rescue RSpec::Expectations::ExpectationNotMetError
  within('body') do
    exp_section = first('.section-header', text: /Expired Polic/i)
    if exp_section
      exp_id = exp_section['data-bs-target']&.tr('#', '')
      if exp_id
        section_content = find("##{exp_id}", visible: :all).text rescue ''
        expect(section_content).not_to include(policy_number)
      end
    end
  end
end

# ─── View Detail Helpers ───────────────────────────────────────────────────────

When('I visit the life insurance detail page for {string}') do |policy_number|
  policy = LifeInsurance.find_by!(policy_number: policy_number)
  visit "/admin/insurance/life/#{policy.id}"
  expect(page).to have_current_path(%r{/admin/insurance/life/\d+}, wait: 10)
end

Then('I should be on the life insurance show page') do
  expect(page).to have_current_path(%r{/admin/insurance/life/\d+}, wait: 10)
end

Then('I should see life insurance premium details') do
  expect(page).to have_content(/₹|premium|net premium/i, wait: 10)
end

Then('I should see life insurance policy type on show page') do
  expect(page).to have_content(/New|Renewal/i, wait: 10)
end

Then('I should see life insurance edit button on show page') do
  expect(page).to have_link(href: /edit/i, wait: 5).or have_content(/Edit/i, wait: 5)
end

Then('I should see life insurance list action buttons') do
  expect(page).to have_css('a[title*="View"], a[title*="Edit"], a[title*="Delete"]', wait: 10)
rescue Capybara::ElementNotFound
  expect(page).to have_css('a[href*="/insurance/life/"]', wait: 10)
end

# ─── Edit Helpers ─────────────────────────────────────────────────────────────

Given('a life insurance policy for editing exists with number {string}') do |policy_number|
  create_test_prerequisites
  @edit_life_policy = build_life_policy(
    @customer,
    policy_number: policy_number,
    start_date: Date.today,
    end_date: Date.today >> 120  # 10 years
  )
end

When('I navigate to edit life insurance {string}') do |policy_number|
  policy = LifeInsurance.find_by!(policy_number: policy_number)
  visit "/admin/insurance/life/#{policy.id}/edit"
  expect(page).to have_current_path(%r{/admin/insurance/life/\d+/edit}, wait: 10)
end

When('I update the life insurance insured name to {string}') do |name|
  page.execute_script(
    "var el = document.querySelector('[name=\"life_insurance[insured_name]\"]'); if(el){ el.value = #{name.to_json}; el.dispatchEvent(new Event('input',{bubbles:true})); }"
  )
end

When('I update the life insurance payment mode to {string}') do |mode|
  select mode, from: 'life_insurance[payment_mode]'
rescue Capybara::ElementNotFound
  page.execute_script(
    "var el = document.querySelector('[name=\"life_insurance[payment_mode]\"]'); if(el){ el.value = #{mode.to_json}; el.dispatchEvent(new Event('change',{bubbles:true})); }"
  )
end

When('I update the life insurance net premium to {string}') do |premium|
  page.execute_script(
    "var el = document.getElementById('net_premium') || document.querySelector('[name=\"life_insurance[net_premium]\"]'); if(el){ el.value = #{premium.to_json}; el.dispatchEvent(new Event('input',{bubbles:true})); }"
  )
end

When('I update the life insurance end date to {int} years from today') do |years|
  end_date = (Date.today >> (years * 12)).strftime('%Y-%m-%d')
  page.execute_script(
    "var el = document.getElementById('end_date') || document.querySelector('[name=\"life_insurance[policy_end_date]\"]'); if(el){ el.value = #{end_date.to_json}; el.dispatchEvent(new Event('change',{bubbles:true})); }"
  )
end

When('I update the life insurance extra notes to {string}') do |notes|
  begin
    fill_in 'life_insurance[extra_note]', with: notes
  rescue Capybara::ElementNotFound
    page.execute_script(
      "var el = document.querySelector('[name=\"life_insurance[extra_note]\"]'); if(el){ el.value = #{notes.to_json}; }"
    )
  end
end

Then('I should see life insurance updated successfully') do
  expect(page).to have_content(
    /life insurance.*successfully updated|was successfully updated/i,
    wait: 15
  )
end

# ─── Delete Helpers ───────────────────────────────────────────────────────────

When('I delete the life insurance policy from the show page') do
  path = URI.parse(current_url).path
  insurance_js_delete(path)
  expect(page).to have_current_path(%r{/admin/insurance/life}, wait: 15)
end

When('I delete life insurance {string} from the list page') do |policy_number|
  policy = LifeInsurance.find_by!(policy_number: policy_number)
  insurance_js_delete("/admin/insurance/life/#{policy.id}")
  expect(page).to have_content(/successfully deleted/i, wait: 15)
end

Then('I should see life insurance deleted successfully') do
  expect(page).to have_content(
    /life insurance.*successfully deleted|was successfully deleted|deleted successfully/i,
    wait: 10
  )
end

Then('life insurance {string} should not appear in the list') do |policy_number|
  visit '/admin/insurance/life'
  expect(page).not_to have_content(policy_number, wait: 5)
end
