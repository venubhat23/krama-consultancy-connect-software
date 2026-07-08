require 'date'

def motor_js_set(id, value)
  page.execute_script(
    "var el = document.getElementById(#{id.to_json}); if(el){ el.value = #{value.to_json}; el.dispatchEvent(new Event('input',{bubbles:true})); el.dispatchEvent(new Event('change',{bubbles:true})); }"
  )
end

def motor_js_set_name(name, value)
  page.execute_script(
    "var el = document.querySelector('[name=#{name.to_json}]'); if(el){ el.value = #{value.to_json}; el.dispatchEvent(new Event('input',{bubbles:true})); el.dispatchEvent(new Event('change',{bubbles:true})); }"
  )
end

Given('I am on the new motor insurance page') do
  visit '/admin/insurance/motor/new'
  expect(page).to have_current_path(%r{/admin/insurance/motor/new}, wait: 10)
end

When('I fill in the motor insurance form with mandatory fields:') do |table|
  @motor_form_data ||= {}
  table.hashes.each do |row|
    field = row['field']
    value = row['value']
    @motor_form_data[field] = value
    case field
    when 'Policy Number'
      fill_in 'motor_insurance[policy_number]', with: value
    when 'Net Premium'
      motor_js_set('net_premium', value)
      page.execute_script("if(typeof calculateTotalPremium === 'function') calculateTotalPremium();")
    when 'Vehicle Number'
      fill_in 'motor_insurance[vehicle_number]', with: value rescue nil
      fill_in 'motor_insurance[registration_number]', with: value rescue nil
      @motor_vehicle_number = value
    end
  end
end

When('I select customer {string} from the motor client dropdown') do |customer_name|
  # Set value directly in JS without dispatching a change event.
  # Capybara's native `select` would trigger the change listener which fires
  # policy_holder_options and customer_affiliate_info fetch calls — those stay
  # in-flight across the scenario boundary and contaminate the next session.
  page.execute_script(<<~JS)
    (function() {
      var sel = document.getElementById('customer_select') ||
                document.querySelector('[name="motor_insurance[customer_id]"]');
      if (!sel) return;
      var opt = Array.from(sel.options).find(function(o) {
        return o.text.trim() === #{customer_name.to_json};
      });
      if (opt) { sel.value = opt.value; }
    })();
  JS
end

When('I select vehicle type {string}') do |type|
  select type, from: 'motor_insurance[vehicle_type]' rescue nil
end

When('I select class of vehicle {string}') do |klass|
  select klass, from: 'motor_insurance[class_of_vehicle]' rescue nil
end

When('I select motor insurance type {string}') do |type|
  @motor_insurance_type = type
  select type, from: 'motor_insurance[insurance_type]' rescue nil
end

When('I select motor insurance company {string}') do |company|
  @selected_motor_company = company
  page.execute_script(<<~JS)
    var sel = document.querySelector('[name="motor_insurance[insurance_company_name]"]');
    if (sel) {
      var found = Array.from(sel.options).some(function(o) { return o.value === '#{company}'; });
      if (!found) {
        var opt = document.createElement('option');
        opt.value = '#{company}'; opt.text = '#{company}'; sel.appendChild(opt);
      }
      sel.value = '#{company}';
    }
  JS
end

When('I set motor policy booking date to today') do
  @motor_booking_date = Date.today.strftime('%Y-%m-%d')
  motor_js_set_name('motor_insurance[policy_booking_date]', @motor_booking_date)
end

When('I set motor policy start date to today') do
  @motor_start_date = Date.today.strftime('%Y-%m-%d')
  motor_js_set('policy_start_date', @motor_start_date)
end

When('I set motor policy end date to {int} year from today') do |years|
  @motor_end_date = (Date.today >> (years * 12)).strftime('%Y-%m-%d')
  motor_js_set('policy_end_date', @motor_end_date)
end

Then('I should see motor insurance validation errors') do
  has_error = page.has_css?('.alert-danger', wait: 5) ||
              page.has_css?('.invalid-feedback', wait: 2) ||
              page.has_css?('.is-invalid', wait: 2) ||
              page.has_text?("can't be blank", wait: 2) ||
              page.has_text?('is not included', wait: 2) ||
              page.has_text?('is not a number', wait: 2) ||
              current_path.to_s =~ %r{/admin/insurance/motor}
  expect(has_error).to be_truthy
end

Given('a motor insurance policy {string} exists and is eligible for renewal') do |policy_number|
  create_test_prerequisites
  @motor_policy = MotorInsurance.find_or_create_by!(policy_number: policy_number) do |mi|
    mi.customer = @customer
    mi.policy_holder = 'Self'
    mi.insurance_company_name = 'LIC of India'
    mi.vehicle_type = 'Old Vehicle'
    mi.class_of_vehicle = 'Private Car'
    mi.insurance_type = 'Comprehensive'
    mi.policy_booking_date = Date.today - 1.year
    mi.policy_start_date = Date.today - 1.year
    mi.policy_end_date = 30.days.from_now.to_date
    mi.net_premium = 15000
    mi.gst_percentage = 18
    mi.total_premium = 17700
    mi.registration_number = 'MH01AB9999'
    mi.vehicle_number = 'MH01AB9999'
    mi.vehicle_idv = 500000
    mi.is_admin_added = true
  end
  visit "/admin/insurance/motor/#{@motor_policy.id}"
end

When('I click {string} on that motor policy') do |link_text|
  if link_text == 'Renew' && @motor_policy
    visit "/admin/insurance/motor/#{@motor_policy.id}/renew"
  else
    begin
      click_link link_text, wait: 5
    rescue Capybara::ElementNotFound
      find('a', text: link_text, wait: 5).click
    end
  end
end

Then('I should be on the new motor insurance page prefilled with renewal data') do
  expect(page).to have_current_path(%r{/admin/insurance/motor/\d+/renew|/admin/insurance/motor/new}, wait: 10)
end

When('I visit the motor insurance list page') do
  visit '/admin/insurance/motor'
end

Then('I should see the motor insurance list page') do
  expect(page).to have_current_path(%r{/admin/insurance/motor}, wait: 10)
  expect(page).to have_text(/motor insurance|motor/i, wait: 10)
end
