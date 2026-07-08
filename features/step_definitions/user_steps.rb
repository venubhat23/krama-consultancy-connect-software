require 'date'

# ─── Helpers ──────────────────────────────────────────────────────────────────

def find_or_create_user(first_name, last_name, email, mobile, user_type: 'admin')
  User.find_or_create_by!(email: email) do |u|
    u.first_name = first_name
    u.last_name  = last_name
    u.mobile     = mobile
    u.user_type  = user_type
    u.password   = 'Password@123'
    u.status     = true
  end
end

def user_js_set(name, value)
  page.execute_script(
    "var el = document.querySelector('[name=#{name.to_json}]'); " \
    "if(el){ el.value = #{value.to_json}; " \
    "el.dispatchEvent(new Event('input',{bubbles:true})); " \
    "el.dispatchEvent(new Event('change',{bubbles:true})); }"
  )
end

def fill_user_field(field, value)
  case field
  when 'First Name'
    user_js_set('user[first_name]', value)
  when 'Last Name'
    user_js_set('user[last_name]', value)
  when 'Mobile'
    user_js_set('user[mobile]', value)
  when 'Email'
    user_js_set('user[email]', value)
  when 'User Type'
    select_value = value.downcase.gsub(' ', '_')
    page.execute_script(
      "var el = document.querySelector('select[name=\"user[user_type]\"]'); " \
      "if(el){ el.value = #{select_value.to_json}; " \
      "el.dispatchEvent(new Event('change',{bubbles:true})); }"
    )
  when 'Password'
    user_js_set('user[password]', value)
    user_js_set('user[password_confirmation]', value)
  when 'Status'
    status_value = value.downcase == 'active' ? 'true' : 'false'
    page.execute_script(
      "var el = document.querySelector('select[name=\"user[status]\"]'); " \
      "if(el){ el.value = #{status_value.to_json}; " \
      "el.dispatchEvent(new Event('change',{bubbles:true})); }"
    )
  end
end

# ─── Navigation ───────────────────────────────────────────────────────────────

Given('I am on the new user page') do
  visit '/admin/users/new'
  expect(page).to have_current_path(%r{/admin/users/new}, wait: 10)
end

Given('a user exists with email {string} and mobile {string}') do |email, mobile|
  parts = email.split('@').first.split('.').map(&:capitalize)
  first = parts.first || 'Test'
  last  = parts[1] || 'User'
  find_or_create_user(first, last, email, mobile)
end

Given('a user exists with name {string} email {string} and mobile {string}') do |name, email, mobile|
  parts = name.split(' ', 2)
  find_or_create_user(parts[0], parts[1] || 'User', email, mobile)
end

When('I visit the users list page') do
  visit '/admin/users'
  expect(page).to have_current_path(%r{/admin/users}, wait: 10)
end

# ─── Form Fill ────────────────────────────────────────────────────────────────

When('I fill in the user form with:') do |table|
  table.hashes.each do |row|
    fill_user_field(row['field'], row['value'])
  end
end

# ─── Form Submission ──────────────────────────────────────────────────────────

When('I submit the user form') do
  native_form_submit
  sleep 0.5
end

# ─── View / Edit / Delete ─────────────────────────────────────────────────────

When('I click view on user {string}') do |name|
  visit '/admin/users'
  row = find('tr', text: name, wait: 10)
  within(row) { find('a[title="View"]', wait: 5).click }
end

Then('I should be on the user show page') do
  expect(page).to have_current_path(%r{/admin/users/\d+}, wait: 10)
end

When('I click edit on user {string}') do |name|
  parts = name.split(' ', 2)
  user = User.find_by!(first_name: parts[0], last_name: parts[1] || 'User')
  visit "/admin/users/#{user.id}/edit"
  expect(page).to have_current_path(%r{/admin/users/\d+/edit}, wait: 10)
end

When('I update the user first name to {string}') do |name|
  user_js_set('user[first_name]', name)
end

When('I update the user last name to {string}') do |name|
  user_js_set('user[last_name]', name)
end

When('I update the user email to {string}') do |email|
  user_js_set('user[email]', email)
end

When('I clear the user first name') do
  user_js_set('user[first_name]', '')
end

When('I delete user {string}') do |name|
  visit '/admin/users'
  row = find('tr', text: name, wait: 10)
  delete_link = within(row) { find('a[title="Delete"], button[title="Delete"]', wait: 5) }
  user_path = delete_link['href']
  page.execute_script(<<~JS)
    (function(){
      if (!window.confirm("Are you sure you want to delete this user?")) return;
      var form = document.createElement('form');
      form.method = 'POST';
      form.action = #{user_path.to_json};
      var m = document.createElement('input'); m.type='hidden'; m.name='_method'; m.value='delete'; form.appendChild(m);
      var c = document.createElement('input'); c.type='hidden'; c.name='authenticity_token';
      c.value = document.querySelector('meta[name="csrf-token"]')?.content || '';
      form.appendChild(c);
      document.body.appendChild(form);
      HTMLFormElement.prototype.submit.call(form);
    })();
  JS
  begin
    page.driver.browser.switch_to.alert.accept
  rescue
    nil
  end
  sleep 1
end

# ─── Assertions: Validation ───────────────────────────────────────────────────

Then('I should see user validation error for {string}') do |field_name|
  expect(page).to have_content(
    /#{Regexp.escape(field_name)}.*can't be blank|#{Regexp.escape(field_name)}.*blank|#{Regexp.escape(field_name)}.*required/i,
    wait: 10
  )
end

Then('I should see user duplicate email error') do
  expect(page).to have_content(
    /email.*already.*taken|already.*taken.*email|email.*registered/i,
    wait: 10
  )
end

Then('I should see user duplicate mobile error') do
  expect(page).to have_content(
    /mobile.*already.*taken|already.*taken.*mobile|mobile.*registered/i,
    wait: 10
  )
end

# ─── Assertions: List ────────────────────────────────────────────────────────

Then('I should see user list total count') do
  expect(page).to have_content(/total users|users.*agent|administrators/i, wait: 10)
end

Then('I should see user list action buttons') do
  expect(page).to have_css('a[title="View"], a[title="Edit"]', wait: 10)
end

Then('I should see user status on the list') do
  expect(page).to have_content(/active|inactive|agent|admin/i, wait: 10)
end

Then('I should not see {string} on the users page') do |text|
  expect(page).not_to have_content(text, wait: 5)
end

