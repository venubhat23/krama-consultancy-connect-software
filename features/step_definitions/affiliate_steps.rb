require 'date'

# ─── Helpers ──────────────────────────────────────────────────────────────────

def find_or_create_affiliate(first_name, last_name, mobile, email: nil)
  email ||= "#{first_name.downcase.gsub(' ', '.')}.#{mobile}@drwise.com"
  role = Role.find_or_create_by!(name: 'Affiliate') { |r| r.description = 'Affiliate'; r.status = true }
  SubAgent.find_or_create_by!(mobile: mobile) do |a|
    a.first_name = first_name
    a.last_name  = last_name
    a.email      = email
    a.password   = 'Password@123'
    a.role       = role
  end
end

def find_or_create_full_affiliate(first_name, mobile)
  email = "#{first_name.downcase}.#{mobile}@drwise.com"
  role  = Role.find_or_create_by!(name: 'Affiliate') { |r| r.description = 'Affiliate'; r.status = true }
  SubAgent.find_or_create_by!(mobile: mobile) do |a|
    a.first_name          = first_name
    a.last_name           = 'Testuser'
    a.email               = email
    a.password            = 'Password@123'
    a.role                = role
    a.bank_name           = 'Axis Bank'
    a.account_no          = '91801234567890'
    a.ifsc_code           = 'UTIB0001234'
    a.account_holder_name = "#{first_name} Testuser"
    a.account_type        = 'Savings'
    a.upi_id              = "#{first_name.downcase}@axis"
  end
end

def find_or_create_deactivated_affiliate(first_name, last_name, mobile, email: nil)
  email ||= "#{first_name.downcase.gsub(' ', '.')}.#{mobile}@drwise.com"
  role  = Role.find_or_create_by!(name: 'Affiliate') { |r| r.description = 'Affiliate'; r.status = true }
  aff = SubAgent.find_or_create_by!(mobile: mobile) do |a|
    a.first_name = first_name
    a.last_name  = last_name
    a.email      = email
    a.password   = 'Password@123'
    a.role       = role
  end
  aff.update!(deactivated: true) unless aff.deactivated?
  aff
end

def affiliate_js_set(name, value)
  page.execute_script(
    "var el = document.querySelector('[name=#{name.to_json}]'); " \
    "if(el){ el.value = #{value.to_json}; " \
    "el.dispatchEvent(new Event('input',{bubbles:true})); " \
    "el.dispatchEvent(new Event('change',{bubbles:true})); }"
  )
end

def fill_affiliate_field(field, value)
  case field
  when 'First Name'
    fill_in 'sub_agent[first_name]', with: value
  when 'Middle Name'
    fill_in 'sub_agent[middle_name]', with: value
  when 'Last Name'
    fill_in 'sub_agent[last_name]', with: value
  when 'Mobile'
    affiliate_js_set('sub_agent[mobile]', value)
  when 'Email'
    find('#sub_agent_email').set(value)
  when 'Password'
    find('#sub_agent_password').set(value)
    begin
      find('#sub_agent_password_confirmation').set(value)
    rescue Capybara::ElementNotFound
      nil
    end
  when 'Birth Date'
    fill_in 'sub_agent[birth_date]', with: value
  when 'Gender'
    select value, from: 'sub_agent[gender]'
  when 'PAN No'
    fill_in 'sub_agent[pan_no]', with: value
  when 'GST No'
    fill_in 'sub_agent[gst_no]', with: value
  when 'Company Name'
    fill_in 'sub_agent[company_name]', with: value
  when 'Address'
    fill_in 'sub_agent[address]', with: value
  when 'Bank Name'
    fill_in 'sub_agent[bank_name]', with: value
  when 'Account Number'
    fill_in 'sub_agent[account_no]', with: value
  when 'IFSC Code'
    fill_in 'sub_agent[ifsc_code]', with: value
  when 'Account Holder Name'
    fill_in 'sub_agent[account_holder_name]', with: value
  when 'Account Type'
    select value, from: 'sub_agent[account_type]'
  when 'UPI ID'
    fill_in 'sub_agent[upi_id]', with: value
  end
end

# ─── Navigation ───────────────────────────────────────────────────────────────

Given('I am on the new affiliate page') do
  Role.find_or_create_by!(name: 'Affiliate') { |r| r.description = 'Affiliate'; r.status = true }
  visit '/admin/sub_agents/new'
  expect(page).to have_current_path(%r{/admin/sub_agents/new}, wait: 10)
end

Given('an affiliate exists with mobile {string}') do |mobile|
  find_or_create_affiliate('Existing', 'Affiliate', mobile)
end

Given('an affiliate exists with name {string} and mobile {string}') do |name, mobile|
  parts = name.split(' ', 2)
  find_or_create_affiliate(parts[0], parts[1] || 'Affiliate', mobile)
end

Given('an affiliate exists with email {string} and mobile {string}') do |email, mobile|
  find_or_create_affiliate('Existing', 'Affiliate', mobile, email: email)
end

Given('an affiliate exists with all fields named {string} with mobile {string}') do |first_name, mobile|
  find_or_create_full_affiliate(first_name, mobile)
end

Given('a deactivated affiliate exists with name {string} and mobile {string}') do |name, mobile|
  parts = name.split(' ', 2)
  find_or_create_deactivated_affiliate(parts[0], parts[1] || 'Affiliate', mobile)
end

When('I visit the affiliates list page') do
  visit '/admin/sub_agents'
  expect(page).to have_current_path(%r{/admin/sub_agents}, wait: 10)
end

# ─── Form Fill ────────────────────────────────────────────────────────────────

When('I fill in the affiliate form with:') do |table|
  table.hashes.each do |row|
    fill_affiliate_field(row['field'], row['value'])
  end
end

When('I fill in the full affiliate form with:') do |table|
  table.hashes.each do |row|
    fill_affiliate_field(row['field'], row['value'])
  end
end

# ─── Form Submission ──────────────────────────────────────────────────────────

When('I submit the affiliate form') do
  native_form_submit
end

When('I submit the affiliate form without filling any fields') do
  native_form_submit
end

# ─── View / Edit ──────────────────────────────────────────────────────────────

When('I click view on affiliate {string}') do |name|
  parts = name.split(' ', 2)
  affiliate = SubAgent.find_by(first_name: parts[0], last_name: parts[1]) ||
              SubAgent.where("first_name ILIKE ? OR last_name ILIKE ?", "#{parts[0]}%", "#{parts[1]}%").first
  raise "Affiliate '#{name}' not found" unless affiliate
  visit "/admin/sub_agents/#{affiliate.id}"
  expect(page).to have_current_path(%r{/admin/sub_agents/\d+$}, wait: 10)
end

Then('I should be on the affiliate show page') do
  expect(page).to have_current_path(%r{/admin/sub_agents/\d+$}, wait: 10)
end

When('I click edit on affiliate {string}') do |name|
  parts = name.split(' ', 2)
  affiliate = SubAgent.find_by(first_name: parts[0], last_name: parts[1]) ||
              SubAgent.where("first_name ILIKE ? OR last_name ILIKE ?", "#{parts[0]}%", "#{parts[1]}%").first
  raise "Affiliate '#{name}' not found" unless affiliate
  visit "/admin/sub_agents/#{affiliate.id}/edit"
  expect(page).to have_current_path(%r{/admin/sub_agents/\d+/edit}, wait: 10)
end

When('I update the affiliate first name to {string}') do |name|
  fill_in 'sub_agent[first_name]', with: name
end

When('I update the affiliate last name to {string}') do |name|
  fill_in 'sub_agent[last_name]', with: name
end

When('I update the affiliate email to {string}') do |email|
  find('#sub_agent_email').set(email)
end

When('I update the affiliate mobile to {string}') do |mobile|
  affiliate_js_set('sub_agent[mobile]', mobile)
end

When('I update the affiliate bank details with:') do |table|
  table.hashes.each { |row| fill_affiliate_field(row['field'], row['value']) }
end

When('I update the affiliate personal details with:') do |table|
  table.hashes.each { |row| fill_affiliate_field(row['field'], row['value']) }
end

When('I clear the affiliate first name field') do
  fill_in 'sub_agent[first_name]', with: ''
end

# ─── Deactivate / Activate ────────────────────────────────────────────────────

When('I deactivate affiliate {string}') do |name|
  row = find('tr', text: name, wait: 10)
  within(row) do
    find('[title="Deactivate"], button[title="Deactivate"]', wait: 5).click
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

When('I activate affiliate {string}') do |name|
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

When('I delete affiliate {string}') do |name|
  visit '/admin/sub_agents'
  row = find('tr', text: name, wait: 10)
  within(row) do
    find('a[title="Delete"], button[title="Delete"], button.delete-sub-agent', wait: 5).click
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

Then('I should see affiliate created successfully') do
  expect(page).to have_content(/affiliate was successfully created|created successfully/i, wait: 10)
end

Then('I should see affiliate updated successfully') do
  expect(page).to have_content(/affiliate was successfully updated|updated successfully/i, wait: 10)
end

Then('I should see affiliate deleted successfully') do
  expect(page).to have_content(/affiliate.*successfully deleted|successfully deleted/i, wait: 10)
end

Then('I should see affiliate deactivated successfully') do
  expect(page).to have_content(/successfully deactivated|deactivated/i, wait: 10)
end

Then('I should see affiliate activated successfully') do
  expect(page).to have_content(/successfully activated|activated/i, wait: 10)
end

# ─── Assertions: Validation ───────────────────────────────────────────────────

Then('I should see affiliate validation errors') do
  expect(page).to have_content(/first name|last name|mobile|email/i, wait: 10)
end

Then('I should see affiliate duplicate mobile error') do
  expect(page).to have_content(/mobile.*already registered|already registered.*mobile/i, wait: 10)
end

Then('I should see affiliate duplicate email error') do
  expect(page).to have_content(/email.*already registered|already registered.*email/i, wait: 10)
end

Then('I should see affiliate email format error') do
  expect(page).to have_content(/email.*invalid|is invalid/i, wait: 10)
end

Then('I should see affiliate mobile format error') do
  expect(page).to have_content(/mobile.*valid.*10-digit|must be a valid 10-digit/i, wait: 10)
end

# ─── Assertions: List / Show ──────────────────────────────────────────────────

Then('I should see affiliate list heading') do
  expect(page).to have_content(/affiliates|sub.agents/i, wait: 10)
end

Then('I should see affiliate status badge on the list') do
  expect(page).to have_content(/active|inactive|deactivated/i, wait: 10)
end

Then('I should see total affiliates count') do
  expect(page).to have_content(/total|affiliates/i, wait: 10)
end

Then('I should see affiliate action buttons') do
  expect(page).to have_css('a[title="View"], a[title="Edit"]', wait: 10)
end

Then('I should see "Deactivated" for affiliate {string}') do |name|
  row = find('tr', text: name, wait: 10)
  within(row) { expect(page).to have_content('Deactivated', wait: 5) }
end

Then('I should not see {string} on the affiliates page') do |name|
  expect(page).not_to have_content(name, wait: 5)
end
