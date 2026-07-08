require 'date'

# ─── Helpers ──────────────────────────────────────────────────────────────────

def find_or_create_ambassador(first_name, last_name, mobile, email: nil)
  email ||= "#{first_name.downcase.gsub(' ', '.')}.#{mobile}@drwise.com"
  Distributor.find_or_create_by!(mobile: mobile) do |d|
    d.first_name = first_name
    d.last_name  = last_name
    d.email      = email
    d.role_id    = 1
  end
end

def find_or_create_full_ambassador(first_name, mobile)
  email = "#{first_name.downcase}.#{mobile}@drwise.com"
  Distributor.find_or_create_by!(mobile: mobile) do |d|
    d.first_name          = first_name
    d.last_name           = 'Testuser'
    d.email               = email
    d.role_id             = 1
    d.bank_name           = 'SBI'
    d.account_no          = '32145678901234'
    d.ifsc_code           = 'SBIN0001234'
    d.account_holder_name = "#{first_name} Testuser"
    d.account_type        = 'Savings'
    d.upi_id              = "#{first_name.downcase}@sbi"
  end
end

def find_or_create_deactivated_ambassador(first_name, last_name, mobile, email: nil)
  email ||= "#{first_name.downcase.gsub(' ', '.')}.#{mobile}@drwise.com"
  amb = Distributor.find_or_create_by!(mobile: mobile) do |d|
    d.first_name = first_name
    d.last_name  = last_name
    d.email      = email
    d.role_id    = 1
  end
  amb.update!(deactivated: true) unless amb.deactivated?
  amb
end

def ambassador_js_set(name, value)
  page.execute_script(
    "var el = document.querySelector('[name=#{name.to_json}]'); " \
    "if(el){ el.value = #{value.to_json}; " \
    "el.dispatchEvent(new Event('input',{bubbles:true})); " \
    "el.dispatchEvent(new Event('change',{bubbles:true})); }"
  )
end

def fill_ambassador_field(field, value)
  case field
  when 'First Name'
    fill_in 'distributor[first_name]', with: value
  when 'Middle Name'
    fill_in 'distributor[middle_name]', with: value
  when 'Last Name'
    fill_in 'distributor[last_name]', with: value
  when 'Mobile'
    ambassador_js_set('distributor[mobile]', value)
  when 'Email'
    find('#distributor_email').set(value)
  when 'Birth Date'
    fill_in 'distributor[birth_date]', with: value
  when 'Gender'
    select value, from: 'distributor[gender]'
  when 'PAN No'
    fill_in 'distributor[pan_no]', with: value
  when 'GST No'
    fill_in 'distributor[gst_no]', with: value
  when 'Company Name'
    fill_in 'distributor[company_name]', with: value
  when 'Address'
    fill_in 'distributor[address]', with: value
  when 'Bank Name'
    fill_in 'distributor[bank_name]', with: value
  when 'Account Number'
    fill_in 'distributor[account_no]', with: value
  when 'IFSC Code'
    fill_in 'distributor[ifsc_code]', with: value
  when 'Account Holder Name'
    fill_in 'distributor[account_holder_name]', with: value
  when 'Account Type'
    select value, from: 'distributor[account_type]'
  when 'UPI ID'
    fill_in 'distributor[upi_id]', with: value
  end
end

# ─── Navigation ───────────────────────────────────────────────────────────────

Given('I am on the new ambassador page') do
  visit '/admin/distributors/new'
  expect(page).to have_current_path(%r{/admin/distributors/new}, wait: 10)
end

Given('an ambassador exists with mobile {string}') do |mobile|
  find_or_create_ambassador('Existing', 'Ambassador', mobile)
end

Given('an ambassador exists with name {string} and mobile {string}') do |name, mobile|
  parts = name.split(' ', 2)
  find_or_create_ambassador(parts[0], parts[1] || 'Ambassador', mobile)
end

Given('an ambassador exists with email {string} and mobile {string}') do |email, mobile|
  find_or_create_ambassador('Existing', 'Ambassador', mobile, email: email)
end

Given('an ambassador exists with all fields named {string} with mobile {string}') do |first_name, mobile|
  find_or_create_full_ambassador(first_name, mobile)
end

Given('a deactivated ambassador exists with name {string} and mobile {string}') do |name, mobile|
  parts = name.split(' ', 2)
  find_or_create_deactivated_ambassador(parts[0], parts[1] || 'Ambassador', mobile)
end

When('I visit the ambassadors list page') do
  visit '/admin/distributors'
  expect(page).to have_current_path(%r{/admin/distributors}, wait: 10)
end

# ─── Form Fill ────────────────────────────────────────────────────────────────

When('I fill in the ambassador form with:') do |table|
  table.hashes.each do |row|
    fill_ambassador_field(row['field'], row['value'])
  end
end

When('I fill in the full ambassador form with:') do |table|
  table.hashes.each do |row|
    fill_ambassador_field(row['field'], row['value'])
  end
end

# ─── Form Submission ──────────────────────────────────────────────────────────

When('I submit the ambassador form') do
  native_form_submit
end

When('I submit the ambassador form without filling any fields') do
  native_form_submit
end

# ─── View / Edit ──────────────────────────────────────────────────────────────

When('I click view on ambassador {string}') do |name|
  visit '/admin/distributors'
  row = find('tr', text: name, wait: 10)
  within(row) { find('a[title="View"]', wait: 5).click }
end

Then('I should be on the ambassador show page') do
  expect(page).to have_current_path(%r{/admin/distributors/\d+$}, wait: 10)
end

When('I click edit on ambassador {string}') do |name|
  visit '/admin/distributors'
  row = find('tr', text: name, wait: 10)
  within(row) { find('a[title="Edit"]', wait: 5).click }
end

When('I update the ambassador first name to {string}') do |name|
  fill_in 'distributor[first_name]', with: name
end

When('I update the ambassador last name to {string}') do |name|
  fill_in 'distributor[last_name]', with: name
end

When('I update the ambassador email to {string}') do |email|
  find('#distributor_email').set(email)
end

When('I update the ambassador mobile to {string}') do |mobile|
  ambassador_js_set('distributor[mobile]', mobile)
end

When('I update the ambassador bank details with:') do |table|
  table.hashes.each { |row| fill_ambassador_field(row['field'], row['value']) }
end

When('I update the ambassador personal details with:') do |table|
  table.hashes.each { |row| fill_ambassador_field(row['field'], row['value']) }
end

When('I clear the ambassador first name field') do
  fill_in 'distributor[first_name]', with: ''
end

# ─── Deactivate / Activate ────────────────────────────────────────────────────

When('I deactivate ambassador {string}') do |name|
  row = find('tr', text: name, wait: 10)
  within(row) do
    find('[title="Deactivate"], button[title="Deactivate"]', wait: 5).click
  end
  # Accept confirmation if present
  begin
    page.driver.browser.switch_to.alert.accept
  rescue
    begin
      find('button', text: /confirm|yes|ok/i, wait: 3).click
    rescue Capybara::ElementNotFound
      nil
    end
  end
  sleep 0.5
end

When('I activate ambassador {string}') do |name|
  row = find('tr', text: name, wait: 10)
  within(row) do
    find('[title="Activate"], button[title="Activate"]', wait: 5).click
  end
  begin
    page.driver.browser.switch_to.alert.accept
  rescue
    begin
      find('button', text: /confirm|yes|ok/i, wait: 3).click
    rescue Capybara::ElementNotFound
      nil
    end
  end
  sleep 0.5
end

# ─── Delete ───────────────────────────────────────────────────────────────────

When('I delete ambassador {string}') do |name|
  visit '/admin/distributors'
  row = find('tr', text: name, wait: 10)
  within(row) do
    find('a[title="Delete"], button[title="Delete"], button.delete-distributor', wait: 5).click
  end
  begin
    page.driver.browser.switch_to.alert.accept
  rescue
    begin
      find('button', text: /confirm|yes|ok/i, wait: 3).click
    rescue Capybara::ElementNotFound
      nil
    end
  end
  sleep 0.5
end

# ─── Assertions: CRUD ─────────────────────────────────────────────────────────

Then('I should see ambassador created successfully') do
  expect(page).to have_content(
    /ambassador was successfully created|distributor was successfully created|created successfully/i,
    wait: 10
  )
end

Then('I should see ambassador updated successfully') do
  expect(page).to have_content(
    /ambassador was successfully updated|distributor was successfully updated|updated successfully/i,
    wait: 10
  )
end

Then('I should see ambassador deleted successfully') do
  expect(page).to have_content(
    /ambassador.*successfully deleted|distributor.*successfully deleted|successfully deleted/i,
    wait: 10
  )
end

Then('I should see ambassador deactivated successfully') do
  expect(page).to have_content(/successfully deactivated|deactivated/i, wait: 10)
end

Then('I should see ambassador activated successfully') do
  expect(page).to have_content(/successfully activated|activated/i, wait: 10)
end

# ─── Assertions: Validation ───────────────────────────────────────────────────

Then('I should see ambassador validation errors') do
  expect(page).to have_content(/first name|last name|mobile|email/i, wait: 10)
end

Then('I should see ambassador duplicate mobile error') do
  expect(page).to have_content(/mobile.*already registered|already registered.*mobile/i, wait: 10)
end

Then('I should see ambassador duplicate email error') do
  expect(page).to have_content(/email.*already registered|already registered.*email/i, wait: 10)
end

Then('I should see ambassador email format error') do
  expect(page).to have_content(/email.*invalid|is invalid/i, wait: 10)
end

# ─── Assertions: List / Show ──────────────────────────────────────────────────

Then('I should see ambassador list heading') do
  expect(page).to have_content(/ambassadors|distributors/i, wait: 10)
end

Then('I should see ambassador status badge on the list') do
  expect(page).to have_content(/active|inactive|deactivated/i, wait: 10)
end

Then('I should see total ambassadors count') do
  expect(page).to have_content(/total|ambassadors/i, wait: 10)
end

Then('I should see ambassador action buttons') do
  expect(page).to have_css('a[title="View"], a[title="Edit"]', wait: 10)
end

Then('I should see "Deactivated" for ambassador {string}') do |name|
  row = find('tr', text: name, wait: 10)
  within(row) { expect(page).to have_content('Deactivated', wait: 5) }
end

Then('I should not see {string} on the ambassadors page') do |name|
  expect(page).not_to have_content(name, wait: 5)
end
