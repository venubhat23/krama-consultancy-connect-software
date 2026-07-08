require 'date'

# ─── Helpers ──────────────────────────────────────────────────────────────────

def cs_js_set(selector, value)
  page.execute_script(<<~JS)
    var el = document.querySelector(#{selector.to_json});
    if (el) {
      el.value = #{value.to_json};
      el.dispatchEvent(new Event('input',  { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
    }
  JS
end

def cs_ensure_authenticated
  return unless page.current_path =~ %r{/users/sign_in}
  find('#user_login').set('testadmin@drwise.com')
  find('#user_password').set('password123')
  click_button 'Sign In'
  expect(page).to have_current_path(%r{/admin|/dashboard}, wait: 15)
end


def create_client_service_record(service_type)
  customer = @cs_customer || Customer.find_or_create_by!(mobile: '9911001100') do |c|
    c.first_name            = 'Service'
    c.last_name             = 'Customer'
    c.customer_type         = 'individual'
    c.email                 = 'service.customer@test.com'
    c.birth_date            = '1990-01-01'
    c.nominee_name          = 'Nominee'
    c.nominee_relation      = 'spouse'
    c.nominee_date_of_birth = '1992-01-01'
    c.status                = true
  end
  category = service_type.split('_').first == 'credit' ? 'credit_card' : service_type.split('_').first
  ClientService.create!(
    service_type:     service_type,
    service_category: category,
    customer_id:      customer.id,
    amount:           5000,
    status:           'pending',
    start_date:       Date.today,
    is_admin_added:   true
  )
end

# ─── Background Setup ─────────────────────────────────────────────────────────

Given('a client service customer exists') do
  @cs_customer = Customer.find_or_create_by!(mobile: '9911001100') do |c|
    c.first_name            = 'Service'
    c.last_name             = 'Customer'
    c.customer_type         = 'individual'
    c.email                 = 'service.customer@test.com'
    c.birth_date            = '1990-01-01'
    c.nominee_name          = 'Nominee'
    c.nominee_relation      = 'spouse'
    c.nominee_date_of_birth = '1992-01-01'
    c.status                = true
  end
end

Given('a lead exists with a converted customer') do
  @cs_customer = Customer.find_or_create_by!(mobile: '9911001101') do |c|
    c.first_name            = 'Lead'
    c.last_name             = 'Customer'
    c.customer_type         = 'individual'
    c.email                 = 'lead.customer@test.com'
    c.birth_date            = '1990-01-01'
    c.nominee_name          = 'Nominee'
    c.nominee_relation      = 'spouse'
    c.nominee_date_of_birth = '1992-01-01'
    c.status                = true
  end
  @cs_lead = Lead.find_or_create_by!(contact_number: '9911001101') do |l|
    l.name                  = 'Lead Customer'
    l.first_name            = 'Lead'
    l.last_name             = 'Customer'
    l.email                 = 'lead.customer@test.com'
    l.converted_customer_id = @cs_customer.id
    l.current_stage         = 'converted'
    l.created_date          = Date.today
    l.lead_source           = 'online'
    l.product_category      = 'investments'
    l.product_subcategory   = 'mutual_fund'
    l.customer_type         = 'individual'
    l.is_direct             = true
  end
end

Given('a client service record exists for {string}') do |service_type|
  @cs_record = create_client_service_record(service_type)
end

# ─── Navigation ───────────────────────────────────────────────────────────────

When('I visit the client services list for {string}') do |service_type|
  visit "/admin/client_services?service_type=#{service_type}"
  cs_ensure_authenticated
  expect(page).to have_current_path(%r{/admin/client_services}, wait: 10)
end

When('I visit the new client service page for {string}') do |service_type|
  url = "/admin/client_services/new?service_type=#{service_type}"
  url += "&customer_id=#{@cs_customer.id}" if @cs_customer
  visit url
  cs_ensure_authenticated
  visit url if page.current_path !~ %r{/admin/client_services/new}
  expect(page).to have_current_path(%r{/admin/client_services/new}, wait: 10)
  cs_js_set('.cs-sub-pct', '0')
end

When('I visit the new client service page with lead and customer params for {string}') do |service_type|
  url = "/admin/client_services/new?service_type=#{service_type}"
  url += "&customer_id=#{@cs_customer.id}" if @cs_customer
  url += "&lead_id=#{@cs_lead.id}" if @cs_lead
  visit url
  cs_ensure_authenticated
  visit url if page.current_path !~ %r{/admin/client_services/new}
  expect(page).to have_current_path(%r{/admin/client_services/new}, wait: 10)
end

# ─── List / Show / Edit / Delete actions ──────────────────────────────────────

When('I click view on the first client service record') do
  row = find('.commission-table tbody tr, table tbody tr', wait: 10, match: :first)
  within(row) { find('a[title="View"]', wait: 5).click }
end

When('I click edit on the first client service record') do
  row = find('.commission-table tbody tr, table tbody tr', wait: 10, match: :first)
  within(row) { find('a[title="Edit"]', wait: 5).click }
  expect(page).to have_current_path(%r{/admin/client_services/\d+/edit}, wait: 10)
end

When('I update the client service amount to {string}') do |amount|
  cs_js_set('#cs_amount', amount)
end

When('I delete the first client service record') do
  row = find('.commission-table tbody tr, table tbody tr', wait: 10, match: :first)
  page.execute_script("window.confirm = function() { return true; }")
  within(row) { find('[title="Delete"]', wait: 5).click }
  expect(page).to have_current_path(%r{/admin/client_services}, wait: 10)
end

# ─── Form Fill & Submit ───────────────────────────────────────────────────────

When('I fill in the minimum client service fields') do
  cs_js_set('#cs_amount', '5000')
  page.execute_script(<<~JS)
    var d = document.querySelector('[name="client_service[start_date]"]');
    if (d) { d.value = '2026-01-01'; d.dispatchEvent(new Event('change', {bubbles:true})); }
  JS
end

When('I submit the client service form') do
  native_form_submit('#cs-form')
end

# ─── Commission Input Steps ───────────────────────────────────────────────────

When('I set the investment amount to {string}') do |amount|
  cs_js_set('#cs_amount', amount)
end

When('I set the main agent commission percentage to {string}') do |pct|
  cs_js_set('#cs_commission_pct', pct)
end

When('I set the investor commission percentage to {string}') do |pct|
  cs_js_set('.cs-inv-pct', pct)
end

When('I set the company expenses percentage to {string}') do |pct|
  cs_js_set('.cs-exp-pct', pct)
end

# ─── Assertions ───────────────────────────────────────────────────────────────

Then('I should be on the client services list page') do
  expect(page).to have_current_path(%r{/admin/client_services}, wait: 10)
  expect(page).to have_css('.card, table', wait: 5)
end

Then('I should be on the client service show page') do
  expect(page).to have_current_path(%r{/admin/client_services/\d+}, wait: 10)
end

Then('the investor actual amount should equal {string}') do |expected|
  actual = page.evaluate_script(<<~JS)
    (function() {
      var rows = document.querySelectorAll('.commission-table tbody tr');
      if (!rows[3]) return null;
      var inputs = rows[3].querySelectorAll('input[type="number"]');
      return inputs[2] ? inputs[2].value : null;
    })()
  JS
  expect(actual).to eq(expected)
end

Then('the company actual amount should equal {string}') do |expected|
  actual = page.evaluate_script(<<~JS)
    (function() {
      var rows = document.querySelectorAll('.commission-table tbody tr');
      if (!rows[4]) return null;
      var inputs = rows[4].querySelectorAll('input[type="number"]');
      return inputs[2] ? inputs[2].value : null;
    })()
  JS
  expect(actual).to eq(expected)
end

Then('the profit percentage should equal {string}') do |expected|
  actual = page.evaluate_script("document.getElementById('cs_profit_pct')?.value")
  expect(actual).to eq(expected)
end

Then('the profit amount should equal {string}') do |expected|
  actual = page.evaluate_script("document.getElementById('cs_profit_amt')?.value")
  expect(actual).to eq(expected)
end

Then('the last created client service should be marked as admin added') do
  record = ClientService.order(:created_at).last
  expect(record).not_to be_nil
  expect(record.is_admin_added).to be true
end
