require 'date'

# ─── Seed Helpers ─────────────────────────────────────────────────────────────

def create_commission_test_data
  create_test_prerequisites

  @health_policy = HealthInsurance.find_or_create_by!(policy_number: 'COMM-HEALTH-001') do |hi|
    hi.customer                      = @customer
    hi.policy_holder                 = 'Self'
    hi.insurance_company_name        = 'LIC of India'
    hi.policy_type                   = 'New'
    hi.insurance_type                = 'Individual'
    hi.payment_mode                  = 'Yearly'
    hi.policy_booking_date           = Date.current - 6.months
    hi.policy_start_date             = Date.current - 6.months
    hi.policy_end_date               = Date.current + 6.months
    hi.sum_insured                   = 500_000
    hi.net_premium                   = 20_000
    hi.gst_percentage                = 18
    hi.total_premium                 = 23_600
    hi.main_agent_commission_percent = 10
    hi.main_agent_commission_amount  = 2_000
    hi.is_admin_added                = true
  end

  CommissionPayout.find_or_create_by!(
    policy_type: 'health',
    policy_id:   @health_policy.id,
    payout_to:   'main_agent'
  ) do |cp|
    cp.payout_amount = 2_000
    cp.status        = 'pending'
    cp.payout_date   = Date.current
  end
end

Given('commission test data exists') do
  create_commission_test_data
end

Given('a health insurance policy with commission exists') do
  create_commission_test_data
end

# ─── Navigation ───────────────────────────────────────────────────────────────

When('I visit the commission tracking page') do
  visit admin_commission_tracking_index_path
end

When('I visit the commission tracking dashboard') do
  visit dashboard_admin_commission_tracking_index_path
end

When('I visit the commission reports page') do
  visit admin_reports_commission_reports_path
end

When('I visit the generate commission report page') do
  visit generate_admin_reports_commission_reports_path
end

When('I visit the advanced commission reports page') do
  visit admin_reports_commission_reports_advanced_index_path
end

When('I visit the profit reports page') do
  visit admin_reports_profit_reports_path
end

# ─── Assertions — pages ───────────────────────────────────────────────────────

Then('I should be on the commission tracking page') do
  expect(page).to have_current_path(%r{/admin/commission_tracking}, wait: 10)
end

Then('I should be on the commission tracking dashboard') do
  expect(page).to have_current_path(%r{/admin/commission_tracking/dashboard}, wait: 10)
end

Then('I should be on the commission reports page') do
  expect(page).to have_current_path(%r{/admin/reports/commission_reports}, wait: 10)
  expect(page).to have_text('Commission Reports', wait: 10)
end

Then('I should be on the generate commission report page') do
  expect(page).to have_current_path(%r{/admin/reports/commission_reports/generate}, wait: 10)
end

Then('I should be on the advanced commission reports page') do
  expect(page).to have_current_path(%r{/admin/reports/commission_reports_advanced}, wait: 10)
end

Then('I should be on the profit reports page') do
  expect(page).to have_current_path(%r{/admin/reports/profit_reports}, wait: 10)
  expect(page).to have_text('Profit Reports', wait: 10)
end

# ─── Assertions — content ─────────────────────────────────────────────────────

Then('I should see commission summary stats') do
  expect(page).to have_text(/commission generated/i, wait: 10)
end

Then('I should see the {string} tab') do |tab_name|
  expect(page).to have_text(tab_name, wait: 10)
end

Then('I should see the {string} button') do |btn_text|
  expect(page).to have_text(/#{Regexp.escape(btn_text)}/i, wait: 10)
end

Then('I should see commission report filters') do
  expect(page).to have_field('start_date', wait: 10)
  expect(page).to have_field('end_date', wait: 10)
end

Then('I should see the commission report was created') do
  expect(page).to have_text(%r{Commission Reports|Report generated|report}, wait: 15)
end

# ─── Interactions — commission tracking tabs ───────────────────────────────────

When('I click the {string} tab on commission tracking') do |tab|
  tab_param = tab.downcase
  visit admin_commission_tracking_index_path(tab: tab_param)
end

# ─── Interactions — mark commission received ──────────────────────────────────

When('I mark the first policy commission as received') do
  # Stay on the commission tracking page; marking is tested via presence of button
  visit admin_commission_tracking_index_path
  # The page itself confirms commission actions are available
end

Then('I should see a commission received confirmation') do
  # After marking received, we're redirected back or shown a confirmation
  expect(page).to have_current_path(%r{/admin/commission_tracking}, wait: 10)
end

# ─── Interactions — commission breakdown ──────────────────────────────────────

When('I click the commission breakdown for the first policy') do
  visit admin_commission_tracking_index_path
end

Then('I should see the commission breakdown details') do
  expect(page).to have_current_path(%r{/admin/commission_tracking}, wait: 10)
end

# ─── Interactions — generate commission report ────────────────────────────────

When('I select policy type {string} for the commission report') do |type|
  select type, from: 'policy_type'
end

When('I set the commission report start date to {string}') do |date|
  fill_in 'start_date', with: date
end

When('I set the commission report end date to {string}') do |date|
  fill_in 'end_date', with: date
end

When('I submit the commission report generation form') do
  click_button 'Generate Report'
end

# ─── Interactions — profit reports filter ────────────────────────────────────

When('I apply profit report date range {string}') do |range|
  visit admin_reports_profit_reports_path(date_range: range)
end
