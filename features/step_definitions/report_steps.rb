require 'date'

# ─── Seed Helpers ─────────────────────────────────────────────────────────────

def create_report_test_data
  create_test_prerequisites
end

def create_expired_health_policy
  create_test_prerequisites
  HealthInsurance.find_or_create_by!(policy_number: 'RPT-EXPIRED-001') do |hi|
    hi.customer               = @customer
    hi.policy_holder          = 'Self'
    hi.insurance_company_name = 'LIC of India'
    hi.policy_type            = 'New'
    hi.insurance_type         = 'Individual'
    hi.payment_mode           = 'Yearly'
    hi.policy_booking_date    = Date.current - 2.years
    hi.policy_start_date      = Date.current - 2.years
    hi.policy_end_date        = Date.current - 30.days
    hi.sum_insured            = 500_000
    hi.net_premium            = 18_000
    hi.gst_percentage         = 18
    hi.total_premium          = 21_240
    hi.is_admin_added         = true
  end
end

def create_expiring_soon_health_policy
  create_test_prerequisites
  HealthInsurance.find_or_create_by!(policy_number: 'RPT-EXPIRING-001') do |hi|
    hi.customer               = @customer
    hi.policy_holder          = 'Self'
    hi.insurance_company_name = 'LIC of India'
    hi.policy_type            = 'New'
    hi.insurance_type         = 'Individual'
    hi.payment_mode           = 'Yearly'
    hi.policy_booking_date    = Date.current - 11.months
    hi.policy_start_date      = Date.current - 11.months
    hi.policy_end_date        = Date.current + 20.days
    hi.sum_insured            = 500_000
    hi.net_premium            = 18_000
    hi.gst_percentage         = 18
    hi.total_premium          = 21_240
    hi.is_admin_added         = true
  end
end

def create_saved_all_policy_report
  create_test_prerequisites
  user = User.find_by(email: 'testadmin@drwise.com')
  Report.find_or_create_by!(name: 'Test All Policy Report') do |r|
    r.report_type  = 'commission'
    r.status       = true
    r.created_by   = user
    r.filters      = { policy_type: 'health' }
    r.report_data  = {}
  end
end

Given('report test data exists') do
  create_report_test_data
end

Given('an expired health insurance policy exists') do
  create_expired_health_policy
end

Given('a health insurance policy expiring within 30 days exists') do
  create_expiring_soon_health_policy
end

Given('a saved all-policy report exists') do
  create_saved_all_policy_report
end

# ─── Navigation ───────────────────────────────────────────────────────────────

When('I visit the expired insurance reports page') do
  visit admin_reports_expired_insurance_reports_path
end

When('I visit the upcoming renewal reports page') do
  visit admin_reports_upcoming_renewal_reports_path
end

When('I visit the payment due reports page') do
  visit admin_reports_payment_due_reports_path
end

When('I visit the all policy reports page') do
  visit admin_reports_all_policy_reports_path
end

When('I visit the new all policy report page') do
  visit new_admin_reports_all_policy_report_path
end

When('I visit the leads reports page') do
  visit admin_reports_lead_reports_path
end

When('I visit the upcoming payment reports page') do
  visit admin_reports_upcoming_payment_reports_path
end

# ─── Assertions — pages ───────────────────────────────────────────────────────

Then('I should be on the expired insurance reports page') do
  expect(page).to have_current_path(%r{/admin/reports/expired_insurance_reports}, wait: 10)
end

Then('I should be on the upcoming renewal reports page') do
  expect(page).to have_current_path(%r{/admin/reports/upcoming_renewal_reports}, wait: 10)
  expect(page).to have_text('Upcoming Renewals', wait: 10)
end

Then('I should be on the payment due reports page') do
  expect(page).to have_current_path(%r{/admin/reports/payment_due_reports}, wait: 10)
  expect(page).to have_text('Payment', wait: 10)
end

Then('I should be on the all policy reports page') do
  expect(page).to have_current_path(%r{/admin/reports/all_policy_reports}, wait: 10)
  expect(page).to have_text('All Policy Reports', wait: 10)
end

Then('I should be on the new all policy report page') do
  expect(page).to have_current_path(%r{/admin/reports/all_policy_reports/new}, wait: 10)
end

Then('I should be on the saved report detail page') do
  expect(page).to have_current_path(%r{/admin/reports/all_policy_reports/\d+}, wait: 10)
end

Then('I should be on the leads reports page') do
  expect(page).to have_current_path(%r{/admin/reports/lead_reports}, wait: 10)
  expect(page).to have_text('Lead Reports', wait: 10)
end

Then('I should be on the upcoming payment reports page') do
  expect(page).to have_current_path(%r{/admin/reports/upcoming_payment_reports}, wait: 10)
  expect(page).to have_text('Upcoming Payment', wait: 10)
end

# ─── Assertions — content ─────────────────────────────────────────────────────

Then('I should see expired policy summary stats') do
  expect(page).to have_css('[class*="stat"], .card', wait: 10)
end

Then('I should see upcoming renewal summary stats') do
  expect(page).to have_text(%r{Renewal|Upcoming}, wait: 10)
end

Then('I should see at least one expired policy record') do
  expect(page).to have_css('table tbody tr', wait: 10)
end

Then('I should see at least one upcoming renewal record') do
  expect(page).to have_css('table tbody tr', wait: 10)
end

Then('I should see the expired insurance report form') do
  expect(page).to have_current_path(%r{expired_insurance_reports/generate}, wait: 10)
end

Then('I should see the upcoming renewal report form') do
  expect(page).to have_current_path(%r{upcoming_renewal_reports/generate}, wait: 10)
end

Then('I should see policy report filter options') do
  expect(page).to have_field('report_name', wait: 10)
  expect(page).to have_select('policy_type', wait: 10)
end

Then('I should see lead report summary stats') do
  expect(page).to have_text(%r{Lead Reports|Total|Reports}, wait: 10)
end

Then('I should see a saved all-policy report') do
  expect(page).to have_text(%r{Policy Report|All Policy|Commission Reports|report}, wait: 15)
end

# ─── Interactions — expired insurance ────────────────────────────────────────

When('I click generate report for expired insurance') do
  visit generate_admin_reports_expired_insurance_reports_path
end

# ─── Interactions — upcoming renewals ────────────────────────────────────────

When('I click generate report for upcoming renewals') do
  visit generate_admin_reports_upcoming_renewal_reports_path
end

# ─── Interactions — all policy reports ───────────────────────────────────────

When('I select policy type {string} for the all-policy report') do |type|
  fill_in 'report_name', with: "#{type} Report #{Date.current}"
  select type, from: 'policy_type'
end

When('I submit the all-policy report form') do
  click_button 'Save Report'
end

When('I click view on the first saved report') do
  first('a[href*="/admin/reports/all_policy_reports/"]', wait: 10)&.click
end

When('I delete the first saved report') do
  accept_confirm do
    first('a[data-method="delete"], button[data-method="delete"]', wait: 10)&.click
  end
end

# ─── Interactions — leads reports filter ──────────────────────────────────────

When('I apply lead report date range {string}') do |range|
  end_date   = Date.current
  start_date = case range
               when '7_days'   then Date.current - 7
               when '30_days'  then Date.current - 30
               when '3_months' then Date.current - 90
               else Date.current - 30
               end
  visit admin_reports_lead_reports_path(start_date: start_date, end_date: end_date)
end

When('I filter leads report by status {string}') do |status|
  visit admin_reports_lead_reports_path(current_stage: status)
end
