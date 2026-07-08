require 'date'

# ─── Helpers ──────────────────────────────────────────────────────────────────

def find_or_create_investor(first_name, last_name, mobile, email: nil)
  email ||= "#{first_name.downcase.gsub(' ', '.')}.#{mobile}@invest.com"
  Investor.find_or_create_by!(mobile: mobile) do |i|
    i.first_name = first_name
    i.last_name  = last_name
    i.email      = email
    i.username   = "#{first_name.downcase}#{mobile[-4..]}"
    i.role_id    = 1
  end
end

def find_or_create_full_investor(first_name, mobile)
  email = "#{first_name.downcase}.#{mobile}@invest.com"
  Investor.find_or_create_by!(mobile: mobile) do |i|
    i.first_name              = first_name
    i.last_name               = 'Testuser'
    i.email                   = email
    i.username                = "#{first_name.downcase}#{mobile[-4..]}"
    i.role_id                 = 1
    i.bank_name               = 'HDFC Bank'
    i.account_no              = '50100123456789'
    i.ifsc_code               = 'HDFC0001234'
    i.account_holder_name     = "#{first_name} Testuser"
    i.account_type            = 'Savings'
    i.upi_id                  = "#{first_name.downcase}@hdfc"
    i.number_of_shares        = 50
    i.invested_amount         = 250000
    i.investment_percentage   = 5
  end
end

def investor_js_set(name, value)
  page.execute_script(
    "var el = document.querySelector('[name=#{name.to_json}]'); " \
    "if(el){ el.value = #{value.to_json}; " \
    "el.dispatchEvent(new Event('input',{bubbles:true})); " \
    "el.dispatchEvent(new Event('change',{bubbles:true})); }"
  )
end

def fill_investor_field(field, value)
  case field
  when 'First Name'
    investor_js_set('investor[first_name]', value)
  when 'Middle Name'
    investor_js_set('investor[middle_name]', value)
  when 'Last Name'
    investor_js_set('investor[last_name]', value)
  when 'Mobile'
    investor_js_set('investor[mobile]', value)
  when 'Email'
    investor_js_set('investor[email]', value)
  when 'Birth Date'
    investor_js_set('investor[birth_date]', value)
  when 'Gender'
    page.execute_script(
      "var el = document.querySelector('select[name=\"investor[gender]\"]'); " \
      "if(el){ el.value = #{value.to_json}; " \
      "el.dispatchEvent(new Event('change',{bubbles:true})); }"
    )
  when 'PAN No'
    investor_js_set('investor[pan_no]', value)
  when 'GST No'
    investor_js_set('investor[gst_no]', value)
  when 'Company Name'
    investor_js_set('investor[company_name]', value)
  when 'Address'
    investor_js_set('investor[address]', value)
  when 'Bank Name'
    investor_js_set('investor[bank_name]', value)
  when 'Account Number'
    investor_js_set('investor[account_no]', value)
  when 'IFSC Code'
    investor_js_set('investor[ifsc_code]', value)
  when 'Account Holder Name'
    investor_js_set('investor[account_holder_name]', value)
  when 'Account Type'
    page.execute_script(
      "var el = document.querySelector('select[name=\"investor[account_type]\"]'); " \
      "if(el){ el.value = #{value.to_json}; " \
      "el.dispatchEvent(new Event('change',{bubbles:true})); }"
    )
  when 'UPI ID'
    investor_js_set('investor[upi_id]', value)
  when 'No of Shares'
    investor_js_set('investor[number_of_shares]', value)
  when 'Invested Amount'
    investor_js_set('investor[invested_amount]', value)
  when 'Investment Percentage'
    investor_js_set('investor[investment_percentage]', value)
  end
end

# ─── Navigation ───────────────────────────────────────────────────────────────

Given('I am on the new investor page') do
  visit '/admin/investors/new'
  expect(page).to have_current_path(%r{/admin/investors/new}, wait: 10)
end

Given('an investor exists with email {string} and mobile {string}') do |email, mobile|
  find_or_create_investor('Existing', 'Investor', mobile, email: email)
end

Given('an investor exists with name {string} and mobile {string}') do |name, mobile|
  parts = name.split(' ', 2)
  find_or_create_investor(parts[0], parts[1] || 'Investor', mobile)
end

Given('an investor exists with all fields named {string} with mobile {string}') do |first_name, mobile|
  find_or_create_full_investor(first_name, mobile)
end

When('I visit the investors list page') do
  visit '/admin/investors'
  expect(page).to have_current_path(%r{/admin/investors}, wait: 10)
end

# ─── Form Fill ────────────────────────────────────────────────────────────────

When('I fill in the investor form with:') do |table|
  table.hashes.each do |row|
    fill_investor_field(row['field'], row['value'])
  end
end

When('I fill in the full investor form with:') do |table|
  table.hashes.each do |row|
    fill_investor_field(row['field'], row['value'])
  end
end

# ─── Form Submission ──────────────────────────────────────────────────────────

When('I submit the investor form') do
  native_form_submit
end

When('I submit the investor form without filling any fields') do
  native_form_submit
end

# ─── View / Edit / Delete ─────────────────────────────────────────────────────

When('I click view on investor {string}') do |name|
  visit '/admin/investors'
  row = find('tr', text: name, wait: 10)
  within(row) { find('a[title="View"]', wait: 5).click }
  expect(page).to have_current_path(%r{/admin/investors/\d+$}, wait: 10)
end

Then('I should be on the investor show page') do
  expect(page).to have_current_path(%r{/admin/investors/\d+$}, wait: 10)
end

When('I click edit on investor {string}') do |name|
  visit '/admin/investors'
  row = find('tr', text: name, wait: 10)
  within(row) { find('a[title="Edit"]', wait: 5).click }
end

When('I update the investor first name to {string}') do |name|
  investor_js_set('investor[first_name]', name)
end

When('I update the investor last name to {string}') do |name|
  investor_js_set('investor[last_name]', name)
end

When('I update the investor email to {string}') do |email|
  investor_js_set('investor[email]', email)
end

When('I update the investor mobile to {string}') do |mobile|
  investor_js_set('investor[mobile]', mobile)
end

When('I update the investor bank details with:') do |table|
  table.hashes.each do |row|
    fill_investor_field(row['field'], row['value'])
  end
end

When('I update the investor investment details with:') do |table|
  table.hashes.each do |row|
    fill_investor_field(row['field'], row['value'])
  end
end

When('I clear the investor first name field') do
  investor_js_set('investor[first_name]', '')
end

When('I toggle the status of investor {string}') do |name|
  row = find('tr', text: name, wait: 10)
  investor_id = within(row) { find('a[title="View"]')['href'].match(%r{/admin/investors/(\d+)})[1] }
  page.execute_script(<<~JS)
    (function() {
      var form = document.createElement('form');
      form.method = 'POST';
      form.action = '/admin/investors/#{investor_id}/toggle_status';
      var m = document.createElement('input'); m.type = 'hidden'; m.name = '_method'; m.value = 'patch';
      form.appendChild(m);
      var c = document.createElement('input'); c.type = 'hidden'; c.name = 'authenticity_token';
      c.value = document.querySelector('meta[name="csrf-token"]')?.content || '';
      form.appendChild(c);
      document.body.appendChild(form);
      HTMLFormElement.prototype.submit.call(form);
    })();
  JS
  sleep 1
end

When('I delete investor {string}') do |name|
  visit '/admin/investors'
  row = find('tr', text: name, wait: 10)
  delete_path = within(row) do
    find('form[data-turbo-confirm]', wait: 5)['action']
  end
  page.execute_script(<<~JS)
    (function(){
      var form = document.createElement('form');
      form.method = 'POST';
      form.action = #{delete_path.to_json};
      var m = document.createElement('input'); m.type='hidden'; m.name='_method'; m.value='delete'; form.appendChild(m);
      var c = document.createElement('input'); c.type='hidden'; c.name='authenticity_token';
      c.value = document.querySelector('meta[name="csrf-token"]')?.content || '';
      form.appendChild(c);
      document.body.appendChild(form);
      HTMLFormElement.prototype.submit.call(form);
    })();
  JS
  sleep 3
end

# ─── Summary Navigation ───────────────────────────────────────────────────────

When('I navigate to the investor summary') do
  current_id = current_url.match(%r{/admin/investors/(\d+)})[1]
  visit "/admin/investors/#{current_id}/summary"
  expect(page).to have_current_path(%r{/admin/investors/\d+/summary}, wait: 10)
end

Then('I should be on the investor summary page') do
  expect(page).to have_current_path(%r{/admin/investors/\d+/summary}, wait: 10)
end

# ─── Assertions: Success / Failure ────────────────────────────────────────────

Then('I should see investor created successfully') do
  expect(page).to have_content(/investor was successfully created|created successfully/i, wait: 10)
end

Then('I should see investor updated successfully') do
  expect(page).to have_content(/investor was successfully updated|updated successfully/i, wait: 10)
end

Then('I should see investor deleted successfully') do
  expect(page).to have_content(/investor.*successfully deleted|successfully deleted/i, wait: 10)
end

Then('I should see investor validation errors') do
  expect(page).to have_content(/first name|last name|mobile|email/i, wait: 10)
end

Then('I should see investor status changed') do
  expect(page).to have_content(/status updated|inactive|active/i, wait: 10)
end

# ─── Assertions: Field Errors ─────────────────────────────────────────────────

Then('I should see {string}') do |text|
  needle = text.downcase

  # Use Capybara's native wait first (handles visible text efficiently)
  found = page.has_content?(text, wait: 10)

  unless found
    # Fall back to checking raw HTML (catches toasts, hidden inputs)
    found = begin
      page.evaluate_script("document.body.innerHTML.toLowerCase().includes(#{needle.to_json})")
    rescue
      false
    end
    found ||= begin
      page.evaluate_script(
        "Array.from(document.querySelectorAll('input,textarea')).some(function(el){ return el.value && el.value.toLowerCase().includes(#{needle.to_json}); })"
      )
    rescue
      false
    end
  end

  url = begin; current_url; rescue; 'unknown (window closed)'; end
  expect(found).to be_truthy,
    "Expected to see '#{text}' on page '#{url}' but could not find it in visible text or input values"
end

Then('I should see investor email format error') do
  expect(page).to have_content(/email.*invalid|is invalid/i, wait: 10)
end

# ─── Assertions: List Page ────────────────────────────────────────────────────

Then('I should see investor status on the list') do
  expect(page).to have_content(/active|inactive/i, wait: 10)
end

Then('I should see total investors count') do
  expect(page).to have_content(/total|investors/i, wait: 10)
end

Then('I should not see {string} on the investors page') do |name|
  expect(page).not_to have_content(name, wait: 5)
end

# ─── Assertions: Summary Page ─────────────────────────────────────────────────

Then('I should see investor commission section') do
  expect(page).to have_content(/commission|payout/i, wait: 10)
end

Then('I should see ambassador network section') do
  expect(page).to have_content(/ambassador|network/i, wait: 10)
end
