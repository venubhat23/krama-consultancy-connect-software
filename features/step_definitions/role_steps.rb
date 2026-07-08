require 'date'

# ─── Helpers ──────────────────────────────────────────────────────────────────

def find_or_create_role(name, description: nil, status: true)
  Role.find_or_create_by!(name: name) do |r|
    r.description = description || "#{name} role"
    r.status      = status
  end
end

def find_or_create_active_role(name)
  role = Role.find_or_create_by!(name: name) do |r|
    r.description = "#{name} role"
    r.status      = true
  end
  role.update!(status: true) unless role.status?
  role
end

def role_js_set(name, value)
  page.execute_script(
    "var el = document.querySelector('[name=#{name.to_json}]'); " \
    "if(el){ el.value = #{value.to_json}; " \
    "el.dispatchEvent(new Event('input',{bubbles:true})); " \
    "el.dispatchEvent(new Event('change',{bubbles:true})); }"
  )
end

# ─── Navigation ───────────────────────────────────────────────────────────────

Given('I am on the new role page') do
  visit '/admin/roles/new'
  expect(page).to have_current_path(%r{/admin/roles/new}, wait: 10)
end

Given('a role exists with name {string}') do |name|
  find_or_create_role(name)
end

Given('a role exists with name {string} and description {string}') do |name, description|
  find_or_create_role(name, description: description)
end

Given('an active role exists with name {string}') do |name|
  find_or_create_active_role(name)
end

When('I visit the roles list page') do
  visit '/admin/roles'
  expect(page).to have_current_path(%r{/admin/roles}, wait: 10)
end

# ─── Form Fill ────────────────────────────────────────────────────────────────

When('I fill in the role form with:') do |table|
  table.hashes.each do |row|
    case row['field']
    when 'Name'
      fill_in 'role[name]', with: row['value']
    when 'Description'
      fill_in 'role[description]', with: row['value']
    when 'Status'
      status_value = row['value'].downcase == 'active' ? 'true' : 'false'
      role_js_set('role[status]', status_value)
    end
  end
end

When('I update the role name to {string}') do |name|
  fill_in 'role[name]', with: name
end

When('I update the role description to {string}') do |description|
  fill_in 'role[description]', with: description
end

When('I clear the role name') do
  fill_in 'role[name]', with: ''
end

# ─── Form Submission ──────────────────────────────────────────────────────────

When('I submit the role form') do
  native_form_submit
end

# ─── View / Edit / Delete / Toggle ───────────────────────────────────────────

When('I click view on role {string}') do |name|
  visit '/admin/roles'
  row = find('tr', text: name, wait: 10)
  within(row) { find('a[title="View Details"]', wait: 5).click }
end

Then('I should be on the role show page') do
  expect(page).to have_current_path(%r{/admin/roles/\d+}, wait: 10)
end

When('I click edit on role {string}') do |name|
  visit '/admin/roles'
  row = find('tr', text: name, wait: 10)
  within(row) { find('a[title="Edit Role"]', wait: 5).click }
end

When('I toggle the status of role {string}') do |name|
  row = find('tr', text: name, wait: 10)
  within(row) do
    find('[title="Deactivate"], [title="Activate"]', wait: 5).click
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

When('I delete role {string}') do |name|
  visit '/admin/roles'
  row = find('tr', text: name, wait: 10)
  within(row) do
    find('[title="Delete Role"], button[title="Delete Role"]', wait: 5).click
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

# ─── Assertions: CRUD ────────────────────────────────────────────────────────

Then('I should see role created successfully') do
  expect(page).to have_content(/role.*successfully created|was successfully created/i, wait: 10)
end

Then('I should see role updated successfully') do
  expect(page).to have_content(/role.*successfully updated|was successfully updated/i, wait: 10)
end

Then('I should see role deleted successfully') do
  expect(page).to have_content(/role.*successfully deleted|was successfully deleted/i, wait: 10)
end

Then('I should see role status changed') do
  expect(page).to have_content(/successfully (activated|deactivated|enabled|disabled)|status/i, wait: 10)
end

# ─── Assertions: Validation ──────────────────────────────────────────────────

Then('I should see role name validation error') do
  expect(page).to have_content(
    /name.*can't be blank|name.*blank|name.*required|please correct/i,
    wait: 10
  )
end

Then('I should see role duplicate name error') do
  expect(page).to have_content(
    /name.*already.*taken|already.*taken.*name|name.*taken/i,
    wait: 10
  )
end

# ─── Assertions: List ────────────────────────────────────────────────────────

Then('I should see roles list heading') do
  expect(page).to have_content(/roles|role management/i, wait: 10)
end

Then('I should see role list action buttons') do
  expect(page).to have_css('a[title="View Details"], a[title="Edit Role"]', wait: 10)
end

Then('I should see role status badge') do
  expect(page).to have_content(/active|inactive/i, wait: 10)
end

Then('I should not see {string} on the roles page') do |name|
  expect(page).not_to have_content(name, wait: 5)
end
