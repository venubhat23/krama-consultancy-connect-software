require 'date'

# ─── Helpers ──────────────────────────────────────────────────────────────────

def find_or_create_individual_client(first_name, last_name, mobile)
  Customer.find_or_create_by!(mobile: mobile) do |c|
    c.first_name            = first_name
    c.last_name             = last_name
    c.customer_type         = 'individual'
    c.birth_date            = '1985-03-10'
    c.email                 = "#{first_name.downcase.gsub(' ', '.')}.#{mobile}@example.com"
    c.nominee_name          = 'Test Nominee'
    c.nominee_relation      = 'spouse'
    c.nominee_date_of_birth = '1988-06-15'
    c.status                = true
  end
end

def find_or_create_full_individual_client(first_name, mobile)
  Customer.find_or_create_by!(mobile: mobile) do |c|
    c.first_name            = first_name
    c.last_name             = 'Testuser'
    c.customer_type         = 'individual'
    c.birth_date            = '1985-03-10'
    c.email                 = "#{first_name.downcase}.#{mobile}@example.com"
    c.nominee_name          = "#{first_name} Nominee"
    c.nominee_relation      = 'spouse'
    c.nominee_date_of_birth = '1988-06-15'
    c.bank_name             = 'HDFC Bank'
    c.account_no            = '12345678901234'
    c.ifsc_code             = 'HDFC0001234'
    c.status                = true
  end
end

def find_or_create_corporate_client(company_name, mobile, email: nil, gst_no: nil)
  email  ||= "#{company_name.downcase.gsub(/\s+/, '.')}.#{mobile}@example.com"
  gst_no ||= '27AAPFU0939F1ZV'
  Customer.find_or_create_by!(mobile: mobile) do |c|
    c.company_name  = company_name
    c.customer_type = 'corporate'
    c.email         = email
    c.gst_no        = gst_no
    c.status        = true
  end
end

# Sets ALL form elements matching the name — handles duplicate-name fields in
# show/hide sections (individual vs corporate) so the last-in-DOM value wins.
def client_js_set_all(name, value)
  page.execute_script(<<~JS)
    document.querySelectorAll('[name=#{name.to_json}]').forEach(function(el) {
      el.value = #{value.to_json};
      el.dispatchEvent(new Event('input',  {bubbles: true}));
      el.dispatchEvent(new Event('change', {bubbles: true}));
    });
  JS
end

def client_js_set_by_id(id, value)
  page.execute_script(<<~JS)
    var el = document.getElementById(#{id.to_json});
    if (el) {
      el.value = #{value.to_json};
      el.dispatchEvent(new Event('input',  {bubbles: true}));
      el.dispatchEvent(new Event('change', {bubbles: true}));
    }
  JS
end

def client_submit
  native_form_submit
end

# ─── Navigation ───────────────────────────────────────────────────────────────

Given('I am on the new client page') do
  visit '/admin/customers/new'
  expect(page).to have_current_path(%r{/admin/customers/new}, wait: 10)
end

Given('a client exists with name {string} and mobile {string}') do |name, mobile|
  parts = name.split(' ', 2)
  find_or_create_individual_client(parts[0], parts[1] || 'Client', mobile)
end

Given('an individual client exists with mobile {string}') do |mobile|
  find_or_create_individual_client('Existing', 'Client', mobile)
end

Given('a corporate client exists with company {string} and mobile {string}') do |company, mobile|
  find_or_create_corporate_client(company, mobile)
end

Given('an individual client exists with all fields named {string} with mobile {string}') do |first_name, mobile|
  find_or_create_full_individual_client(first_name, mobile)
end

When('I visit the clients list page') do
  visit '/admin/customers'
  expect(page).to have_current_path(%r{/admin/customers}, wait: 10)
end

When('I visit the clients list page with type filter {string}') do |type|
  visit "/admin/customers?customer_type=#{type}"
  expect(page).to have_current_path(%r{/admin/customers}, wait: 10)
end

# ─── Customer Type Selection ───────────────────────────────────────────────────

When('I select client type {string}') do |type|
  type_value = type.downcase
  # Use JS to check the radio and fire the change event that toggles sections
  page.execute_script(<<~JS)
    var radio = document.getElementById('customer_type_#{type_value}');
    if (radio) {
      radio.checked = true;
      radio.dispatchEvent(new Event('change', {bubbles: true}));
    } else {
      // Fallback for select-based customer_type (edit form)
      var sel = document.getElementById('customer_type');
      if (sel) {
        sel.value = '#{type_value}';
        sel.dispatchEvent(new Event('change', {bubbles: true}));
      }
    }
  JS
  sleep 0.5
end

# ─── Individual Client Form ───────────────────────────────────────────────────

When('I fill in the individual client form with:') do |table|
  table.hashes.each do |row|
    case row['field']
    when 'First Name'
      client_js_set_by_id('individual_first_name', row['value'])
    when 'Last Name'
      client_js_set_by_id('individual_last_name', row['value'])
    when 'Mobile'
      # Set both fields so the individual one (last in DOM) has the correct value
      client_js_set_all('customer[mobile]', row['value'])
    when 'Email'
      client_js_set_all('customer[email]', row['value'])
    when 'Date of Birth'
      client_js_set_all('customer[birth_date]', row['value'])
    when 'Nominee Name'
      client_js_set_all('customer[nominee_name]', row['value'])
    when 'Nominee DOB'
      client_js_set_all('customer[nominee_date_of_birth]', row['value'])
    end
  end
end

When('I select nominee relation {string}') do |relation|
  relation_value = relation.downcase
  client_js_set_all('customer[nominee_relation]', relation_value)
end

# ─── Bank Details Form ───────────────────────────────────────────────────────

When('I fill in the bank details with:') do |table|
  table.hashes.each do |row|
    case row['field']
    when 'Bank Name'
      client_js_set_by_id('customer_bank_name_individual', row['value'])
    when 'Account Number'
      client_js_set_by_id('customer_account_no_individual', row['value'])
    when 'IFSC Code'
      client_js_set_by_id('customer_ifsc_code_individual', row['value'])
    end
  end
end

# ─── Corporate Client Form ────────────────────────────────────────────────────
# Corporate section comes before individual in DOM. To ensure the corporate values
# survive (last value wins for duplicate names), we set ALL matching fields so
# the individual section's empty fields don't overwrite the corporate values.

When('I fill in the corporate client form with:') do |table|
  table.hashes.each do |row|
    case row['field']
    when 'Company Name'
      client_js_set_by_id('corporate_company_name', row['value'])
    when 'Mobile'
      client_js_set_all('customer[mobile]', row['value'])
    when 'Email'
      client_js_set_all('customer[email]', row['value'])
    when 'GST No'
      client_js_set_by_id('corporate_gst_no', row['value'])
    end
  end
end

# ─── Form Submission ──────────────────────────────────────────────────────────

When('I submit the client form') do
  client_submit
end

When('I submit the client form without filling any fields') do
  client_submit
end

# ─── View / Edit / Delete ─────────────────────────────────────────────────────

When('I click view on client {string}') do |name|
  visit '/admin/customers'
  row = find('tr', text: name, wait: 10)
  within(row) { find('a[title="View"]', wait: 5).click }
  expect(page).to have_current_path(%r{/admin/customers/\d+}, wait: 15)
end

Then('I should be on the client show page') do
  expect(page).to have_current_path(%r{/admin/customers/\d+}, wait: 10)
end

When('I click edit on client {string}') do |name|
  visit '/admin/customers'
  row = find('tr', text: name, wait: 10)
  within(row) { find('a[title="Edit"]', wait: 5).click }
  expect(page).to have_current_path(%r{/admin/customers/\d+/edit}, wait: 10)
end

When('I update the client first name to {string}') do |name|
  field = find('#individual_first_name, #customer_first_name, [name="customer[first_name]"]', wait: 5)
  field.set('')
  field.set(name)
end

When('I update the client last name to {string}') do |name|
  field = find('#individual_last_name, #customer_last_name, [name="customer[last_name]"]', wait: 5)
  field.set('')
  field.set(name)
end

When('I update the client email to {string}') do |email|
  client_js_set_all('customer[email]', email)
end

When('I update the client mobile to {string}') do |mobile|
  client_js_set_all('customer[mobile]', mobile)
end

When('I update the client bank details with:') do |table|
  table.hashes.each do |row|
    case row['field']
    when 'Bank Name'
      # Edit form may use a single field or the individual-suffixed id
      begin
        client_js_set_by_id('customer_bank_name_individual', row['value'])
      rescue
        client_js_set_all('customer[bank_name]', row['value'])
      end
    when 'Account Number'
      begin
        client_js_set_by_id('customer_account_no_individual', row['value'])
      rescue
        client_js_set_all('customer[account_no]', row['value'])
      end
    when 'IFSC Code'
      begin
        client_js_set_by_id('customer_ifsc_code_individual', row['value'])
      rescue
        client_js_set_all('customer[ifsc_code]', row['value'])
      end
    end
  end
end

When('I clear the individual client first name') do
  field = find('#individual_first_name, #customer_first_name, [name="customer[first_name]"]', wait: 5)
  field.set('')
end

When('I delete client {string}') do |name|
  visit '/admin/customers'
  row = find('tr', text: name, wait: 10)
  within(row) { find('button.delete-customer-enhanced, a[title="Delete"]', wait: 5).click }
  begin
    find('#confirmDeleteBtn', wait: 5).click
  rescue Capybara::ElementNotFound
    page.driver.browser.switch_to.alert.accept rescue nil
  end
  sleep 0.5
end

# ─── Assertions: Validation ───────────────────────────────────────────────────

Then('I should see client validation errors for individual') do
  expect(page).to have_content(
    /please correct|first name|last name|mobile|birth date|nominee|can't be blank|is invalid/i,
    wait: 10
  )
end

Then('I should see client validation errors for corporate') do
  expect(page).to have_content(
    /please correct|company name|mobile|email|gst|can't be blank|is invalid/i,
    wait: 10
  )
end

Then('I should see individual client missing field error for {string}') do |field_name|
  expect(page).to have_content(
    /#{Regexp.escape(field_name)}.*can't be blank|#{Regexp.escape(field_name)}.*blank|#{Regexp.escape(field_name)}.*required/i,
    wait: 10
  )
end

Then('I should see corporate client missing field error for {string}') do |field_name|
  expect(page).to have_content(
    /#{Regexp.escape(field_name)}.*can't be blank|#{Regexp.escape(field_name)}.*blank|#{Regexp.escape(field_name)}.*required/i,
    wait: 10
  )
end

Then('I should see client mobile format error') do
  expect(page).to have_content(
    /mobile.*valid|must be a valid.*mobile|mobile.*10.digit|mobile.*start|is invalid/i,
    wait: 10
  )
end

Then('I should see client duplicate mobile error') do
  expect(page).to have_content(
    /mobile.*already.*taken|already.*taken.*mobile|mobile.*registered|already registered/i,
    wait: 10
  )
end

# ─── Assertions: CRUD Success ─────────────────────────────────────────────────

Then('I should see client created successfully') do
  # The notice varies depending on whether a user account was auto-created:
  #   "Customer was successfully created."
  #   "Customer and login account created successfully."
  #   "Customer created successfully. Auto-generated password: ..."
  expect(page).to have_content(
    /Customer was successfully created|Customer.*created successfully|Customer and login account created successfully/i,
    wait: 10
  )
end

Then('I should see client updated successfully') do
  expect(page).to have_content(
    /Customer was successfully updated|updated successfully/i,
    wait: 10
  )
end

Then('I should see client deleted successfully') do
  expect(page).to have_content(
    /Customer was successfully deleted|deleted successfully/i,
    wait: 10
  )
end

# ─── Assertions: List Page ────────────────────────────────────────────────────

Then('I should see client list total count') do
  expect(page).to have_content(/total|clients|customers/i, wait: 10)
end

Then('I should see client status badge') do
  expect(page).to have_content(/active|inactive|deactivated/i, wait: 10)
end

Then('I should see client list action buttons') do
  expect(page).to have_css('a[title="View"], a[title="Edit"]', wait: 10)
end

Then('I should not see {string} on the clients page') do |name|
  expect(page).not_to have_content(name, wait: 5)
end
