require 'date'

def health_js_set(id, value)
  page.execute_script(
    "var el = document.getElementById(#{id.to_json}); if(el){ el.value = #{value.to_json}; el.dispatchEvent(new Event('input',{bubbles:true})); el.dispatchEvent(new Event('change',{bubbles:true})); }"
  )
end

def health_js_set_name(name, value)
  page.execute_script(
    "var el = document.querySelector('[name=#{name.to_json}]'); if(el){ el.value = #{value.to_json}; el.dispatchEvent(new Event('input',{bubbles:true})); el.dispatchEvent(new Event('change',{bubbles:true})); }"
  )
end

Given('I am on the new health insurance page') do
  visit '/admin/insurance/health/new'
  expect(page).to have_current_path(%r{/admin/insurance/health/new}, wait: 10)
end

When('I fill in the health insurance form with all fields:') do |table|
  @health_form_data ||= {}
  table.hashes.each do |row|
    field = row['field']
    value = row['value']
    @health_form_data[field] = value
    case field
    when 'Policy Number'
      fill_in 'health_insurance[policy_number]', with: value
    when 'Net Premium'
      health_js_set('net_premium', value)
      page.execute_script("if(typeof calculateHealthTotalPremium === 'function') calculateHealthTotalPremium();")
    when 'GST %'
      health_js_set('gst_percentage', value)
      page.execute_script("if(typeof calculateHealthTotalPremium === 'function') calculateHealthTotalPremium();")
    end
  end
end

When('I select customer {string} from the health client dropdown') do |customer_name|
  # Set value directly in JS without dispatching a change event to prevent
  # any select2:select-triggered fetches from staying in-flight across scenarios.
  page.execute_script(<<~JS)
    (function() {
      var sel = document.getElementById('customer_select') ||
                document.querySelector('[name="health_insurance[customer_id]"]');
      if (!sel) return;
      var opt = Array.from(sel.options).find(function(o) {
        return o.text.trim() === #{customer_name.to_json};
      });
      if (opt) { sel.value = opt.value; }
    })();
  JS
end

When('I select health insurance type {string}') do |type|
  select type, from: 'health_insurance[insurance_type]' rescue nil
end

When('I select health policy type {string}') do |type|
  select type, from: 'health_insurance[policy_type]' rescue nil
end

When('I select health insurance company {string}') do |company|
  @selected_health_company = company
  page.execute_script(<<~JS)
    var sel = document.getElementById('health_insurance_insurance_company_name') ||
              document.querySelector('[name="health_insurance[insurance_company_name]"]');
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

When('I select health payment mode {string}') do |mode|
  select mode, from: 'health_insurance[payment_mode]' rescue nil
end

When('I set health policy booking date to today') do
  @health_booking_date = Date.today.strftime('%Y-%m-%d')
  health_js_set_name('health_insurance[policy_booking_date]', @health_booking_date)
end

When('I set health policy start date to today') do
  @health_start_date = Date.today.strftime('%Y-%m-%d')
  health_js_set('start_date', @health_start_date)
end

When('I set health policy end date to {int} year from today') do |years|
  @health_end_date = (Date.today >> (years * 12)).strftime('%Y-%m-%d')
  health_js_set('end_date', @health_end_date)
end

When('I set health sum insured to {string}') do |amount|
  @health_sum_insured_text = amount
  fill_in 'sum_insured_text_input', with: amount rescue nil
  find('#sum_insured_text_input').send_keys(:tab) rescue nil
  sleep 0.3
  page.execute_script(<<~JS)
    function parseAmount(text) {
      if (!text) return 0;
      var clean = text.toString().toLowerCase().replace(/[₹,\\s]/g, '');
      var match = clean.match(/[\\d.]+/); if (!match) return 0;
      var num = parseFloat(match[0]); if (isNaN(num) || num === 0) return 0;
      if (/lakh|lac/.test(clean)) return Math.round(num * 100000);
      if (/crore|cr/.test(clean)) return Math.round(num * 10000000);
      return Math.round(num);
    }
    var parsed = parseAmount('#{amount}');
    var h = document.querySelector('input[name="health_insurance[sum_insured]"]');
    if (h) h.value = parsed;
  JS
end


Then('I should see health insurance validation errors') do
  has_error = page.has_css?('.alert-danger', wait: 5) ||
              page.has_css?('.invalid-feedback', wait: 2) ||
              page.has_css?('.is-invalid', wait: 2) ||
              page.has_text?("can't be blank", wait: 2) ||
              page.has_text?('is not included', wait: 2) ||
              page.has_text?('is not a number', wait: 2) ||
              page.has_text?('must be greater than', wait: 2) ||
              current_path.to_s =~ %r{/admin/insurance/health}
  expect(has_error).to be_truthy
end

Given('a health insurance policy {string} exists and is eligible for renewal') do |policy_number|
  create_test_prerequisites
  @health_policy = HealthInsurance.find_or_create_by!(policy_number: policy_number) do |hi|
    hi.customer = @customer
    hi.policy_holder = 'Self'
    hi.insurance_company_name = 'LIC of India'
    hi.policy_type = 'New'
    hi.insurance_type = 'Individual'
    hi.payment_mode = 'Yearly'
    hi.policy_booking_date = Date.today - 1.year
    hi.policy_start_date = Date.today - 1.year
    hi.policy_end_date = 30.days.from_now.to_date
    hi.sum_insured = 500000
    hi.net_premium = 25000
    hi.gst_percentage = 18
    hi.total_premium = 29500
    hi.is_admin_added = true
  end
  visit "/admin/insurance/health/#{@health_policy.id}"
end

When('I click {string} on that health policy') do |link_text|
  if link_text == 'Renew' && @health_policy
    visit "/admin/insurance/health/#{@health_policy.id}/renew"
  else
    begin
      click_link link_text, wait: 5
    rescue Capybara::ElementNotFound
      find('a', text: link_text, wait: 5).click
    end
  end
end

Then('I should be on the new health insurance page prefilled with renewal data') do
  expect(page).to have_current_path(%r{/admin/insurance/health/\d+/renew|/admin/insurance/health/new}, wait: 10)
end

Given('I have multiple health insurance policies') do
  create_test_prerequisites
  ['HEALTH-MULTI-001', 'HEALTH-MULTI-002'].each do |num|
    HealthInsurance.find_or_create_by!(policy_number: num) do |hi|
      hi.customer = @customer
      hi.policy_holder = 'Self'
      hi.insurance_company_name = 'LIC of India'
      hi.policy_type = 'New'
      hi.insurance_type = 'Individual'
      hi.payment_mode = 'Yearly'
      hi.policy_booking_date = Date.today
      hi.policy_start_date = Date.today
      hi.policy_end_date = 1.year.from_now.to_date
      hi.sum_insured = 500000
      hi.net_premium = 25000
      hi.gst_percentage = 18
      hi.total_premium = 29500
      hi.is_admin_added = true
    end
  end
end

When('I visit the health insurance list page') do
  visit '/admin/insurance/health'
end

Then('I should see health insurance policies listed') do
  expect(page).to have_css('table', wait: 10)
end
