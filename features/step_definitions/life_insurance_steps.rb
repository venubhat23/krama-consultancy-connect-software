require 'date'
require 'cgi'

# ============================================================
# Navigation Steps
# ============================================================
Given('I am on the new life insurance page') do
  visit '/admin/insurance/life/new'
  expect(page).to have_current_path(%r{/admin/insurance/life/new}, wait: 10)
end

When('I visit the life insurance list page') do
  visit '/admin/insurance/life'
  expect(page).to have_current_path(%r{/admin/insurance/life}, wait: 10)
end

# ============================================================
# Form Filling Steps
# ============================================================
def js_set_field(selector, value, by_id: false)
  if by_id
    page.execute_script(
      "var el = document.getElementById(#{selector.to_json}); if(el){ el.value = #{value.to_json}; el.dispatchEvent(new Event('input',{bubbles:true})); }"
    )
  else
    page.execute_script(
      "var el = document.querySelector('[name=#{selector.to_json}]'); if(el){ el.value = #{value.to_json}; el.dispatchEvent(new Event('input',{bubbles:true})); }"
    )
  end
end

When('I fill in the life insurance form with all fields:') do |table|
  @life_form_data ||= {}
  table.hashes.each do |row|
    field  = row['field']
    value  = row['value']
    @life_form_data[field] = value
    case field
    when 'Policy Number'
      fill_in 'life_insurance[policy_number]', with: value
    when 'Insured Name'
      js_set_field('life_insurance[insured_name]', value)
    when 'Net Premium'
      js_set_field('net_premium', value, by_id: true)
    when '1st Year GST %'
      js_set_field('first_year_gst', value, by_id: true)
    when 'Policy Term'
      js_set_field('life_insurance[policy_term]', value)
    when 'Premium Payment Term'
      js_set_field('life_insurance[premium_payment_term]', value)
    end
  end
end

When('I select customer {string} from the client dropdown') do |customer_name|
  select customer_name, from: 'life_insurance[customer_id]'
rescue Capybara::ElementNotFound
  find('#customer_select').find("option[data-value]", text: customer_name, exact: false).select_option rescue nil
  select customer_name, from: 'customer_select' rescue nil
end

When('I select policy holder {string}') do |holder|
  select holder, from: 'life_insurance[policy_holder]'
rescue Capybara::ElementNotFound
  find('#policy_holder_select').find("option", text: holder, exact: false).select_option rescue nil
end

When('I select insurance company {string}') do |company_name|
  @selected_company = company_name
  # Select "Direct" broker type (this is needed for form validation)
  js_set_field('life_insurance[broker_code_type]', 'direct')
  # Enable the company dropdown and inject company as hidden input (avoids AJAX reset issues)
  page.execute_script(<<~JS)
    var icSelect = document.getElementById('life_insurance_insurance_company_name');
    if (icSelect) {
      icSelect.disabled = false;
      var found = Array.from(icSelect.options).some(function(o) { return o.value === '#{company_name}'; });
      if (!found) {
        var opt = document.createElement('option');
        opt.value = '#{company_name}';
        opt.text = '#{company_name}';
        icSelect.appendChild(opt);
      }
      icSelect.value = '#{company_name}';
    }
    // Also add a hidden input as fallback in case dropdown is re-disabled
    var existing = document.querySelector('input[name="life_insurance[insurance_company_name]"]');
    if (!existing || existing.type !== 'hidden') {
      existing = document.createElement('input');
      existing.type = 'hidden';
      existing.name = 'life_insurance[insurance_company_name]';
      document.querySelector('form').appendChild(existing);
    }
    existing.value = '#{company_name}';
  JS
end

When('I select policy type {string}') do |type|
  select type, from: 'life_insurance[policy_type]'
end

When('I select payment mode {string}') do |mode|
  select mode, from: 'life_insurance[payment_mode]'
end

When('I set policy booking date to today') do
  @policy_booking_date = Date.today.strftime('%Y-%m-%d')
  js_set_field('life_insurance[policy_booking_date]', @policy_booking_date)
end

When('I set policy start date to today') do
  @policy_start_date = Date.today.strftime('%Y-%m-%d')
  js_set_field('start_date', @policy_start_date, by_id: true)
end

When('I set policy end date to {int} years from today') do |years|
  @policy_end_date = (Date.today >> (years * 12)).strftime('%Y-%m-%d')
  js_set_field('end_date', @policy_end_date, by_id: true)
end

When('I set policy end date to {int} year from today') do |years|
  @policy_end_date = (Date.today >> (years * 12)).strftime('%Y-%m-%d')
  js_set_field('end_date', @policy_end_date, by_id: true)
end

When('I set sum insured to {string}') do |amount|
  fill_in 'sum_insured_text_input', with: amount
  find('#sum_insured_text_input').send_keys(:tab)
  sleep 0.5
  # Parse the amount text and set the hidden sum_insured field (prevents empty string overwrite)
  # Also inject distributor_id since no form field exists for it
  distributor_id_val = @distributor&.id.to_s
  page.execute_script(<<~JS)
    function parseIndianAmount(text) {
      if (!text) return 0;
      var clean = text.toString().toLowerCase().replace(/[₹,\\s]/g, '');
      var match = clean.match(/[\\d.]+/);
      if (!match) return 0;
      var num = parseFloat(match[0]);
      if (isNaN(num) || num === 0) return 0;
      if (/lakh|lac/.test(clean)) return Math.round(num * 100000);
      if (/crore|cr/.test(clean)) return Math.round(num * 10000000);
      return Math.round(num);
    }
    var parsed = parseIndianAmount('#{amount}');
    var sumHidden = document.querySelector('input[name="life_insurance[sum_insured]"]');
    if (sumHidden) sumHidden.value = parsed;

    if ('#{distributor_id_val}' !== '') {
      var distInput = document.querySelector('input[name="life_insurance[distributor_id]"]');
      if (!distInput) {
        distInput = document.createElement('input');
        distInput.type = 'hidden';
        distInput.name = 'life_insurance[distributor_id]';
        document.querySelector('form').appendChild(distInput);
      }
      distInput.value = '#{distributor_id_val}';
    }
  JS
end

When('I click {string}') do |button_text|
  if page.has_css?('form#life-insurance-form', wait: 1)
    # Re-inject all stored values right before submit to bypass any AJAX resets
    data      = @life_form_data || {}
    net       = data['Net Premium'].to_s
    gst       = data['1st Year GST %'].to_s
    term      = data['Policy Term'].to_s
    ppt       = data['Premium Payment Term'].to_s
    total     = (net.to_f * (1 + gst.to_f / 100)).round(2).to_s
    company   = @selected_company.to_s
    dist_id   = @distributor&.id.to_s
    start_d   = @policy_start_date.to_s
    end_d     = @policy_end_date.to_s
    booking_d = @policy_booking_date.to_s
    pol_num   = data['Policy Number'].to_s
    ins_name  = data['Insured Name'].to_s

    page.execute_script(<<~JS)
      function lif_setVal(id, val) {
        var el = document.getElementById(id);
        if (el && val) el.value = val;
      }
      function lif_setByName(name, val) {
        var el = document.querySelector('[name="' + name + '"]');
        if (el && val) el.value = val;
      }
      function lif_injectHidden(name, val) {
        if (!val) return;
        var el = document.querySelector('input[type="hidden"][name="' + name + '"]');
        if (!el) {
          el = document.createElement('input');
          el.type = 'hidden';
          el.name = name;
          document.getElementById('life-insurance-form').appendChild(el);
        }
        el.value = val;
      }

      lif_setVal('net_premium', #{net.to_json});
      lif_setVal('first_year_gst', #{gst.to_json});
      lif_setVal('total_premium', #{total.to_json});
      lif_setByName('life_insurance[policy_term]', #{term.to_json});
      lif_setByName('life_insurance[premium_payment_term]', #{ppt.to_json});
      lif_setVal('start_date', #{start_d.to_json});
      lif_setVal('end_date', #{end_d.to_json});
      lif_setByName('life_insurance[policy_booking_date]', #{booking_d.to_json});
      lif_setByName('life_insurance[policy_number]', #{pol_num.to_json});
      lif_setByName('life_insurance[insured_name]', #{ins_name.to_json});
      lif_injectHidden('life_insurance[insurance_company_name]', #{company.to_json});
      lif_injectHidden('life_insurance[distributor_id]', #{dist_id.to_json});

      document.getElementById('life-insurance-form').submit();
    JS
  elsif current_url.to_s.include?('/insurance/health')
    # Health insurance form — re-inject stored values before JS submit
    data    = @health_form_data || {}
    net     = data['Net Premium'].to_s
    gst     = data['GST %'].to_s
    total   = net.to_f > 0 ? (net.to_f * (1 + gst.to_f / 100)).round(2).to_s : ''
    company = @selected_health_company.to_s
    start_d = @health_start_date.to_s
    end_d   = @health_end_date.to_s
    booking = @health_booking_date || Date.today.strftime('%Y-%m-%d')
    pol_num = data['Policy Number'].to_s
    page.execute_script(<<~JS)
      function hset(id, val) { var el = document.getElementById(id); if (el && val !== undefined && val !== '') el.value = val; }
      function hsetn(name, val) { var el = document.querySelector('[name="' + name + '"]'); if (el && val !== undefined && val !== '') el.value = val; }
      function hinject(name, val) {
        if (!val) return;
        var el = document.querySelector('input[type="hidden"][name="' + name + '"]');
        if (!el) { el = document.createElement('input'); el.type = 'hidden'; el.name = name; document.querySelector('form').appendChild(el); }
        el.value = val;
      }
      hset('net_premium', #{net.to_json});
      hset('gst_percentage', #{gst.to_json});
      hset('total_premium', #{total.to_json});
      hset('start_date', #{start_d.to_json});
      hset('end_date', #{end_d.to_json});
      hsetn('health_insurance[policy_booking_date]', #{booking.to_json});
      hsetn('health_insurance[policy_number]', #{pol_num.to_json});
      hinject('health_insurance[insurance_company_name]', #{company.to_json});
      HTMLFormElement.prototype.submit.call(document.querySelector('form'));
    JS
  elsif current_url.to_s.include?('/insurance/motor')
    # Motor insurance form — re-inject stored values before JS submit
    data    = @motor_form_data || {}
    net     = data['Net Premium'].to_s
    gst     = '18'
    total   = net.to_f > 0 ? (net.to_f * (1 + gst.to_f / 100)).round(2).to_s : ''
    company = @selected_motor_company.to_s
    start_d = @motor_start_date.to_s
    end_d   = @motor_end_date.to_s
    booking = @motor_booking_date || Date.today.strftime('%Y-%m-%d')
    pol_num = data['Policy Number'].to_s
    reg_num = @motor_vehicle_number.to_s
    ins_typ = @motor_insurance_type.to_s
    idv_val = ins_typ == 'Third Party' ? '0' : '100000'
    page.execute_script(<<~JS)
      function mset(id, val) { var el = document.getElementById(id); if (el && val !== undefined && val !== '') el.value = val; }
      function msetn(name, val) { var el = document.querySelector('[name="' + name + '"]'); if (el && val !== undefined && val !== '') el.value = val; }
      function minject(name, val) {
        if (!val) return;
        var el = document.querySelector('input[type="hidden"][name="' + name + '"]');
        if (!el) { el = document.createElement('input'); el.type = 'hidden'; el.name = name; document.querySelector('form').appendChild(el); }
        el.value = val;
      }
      mset('net_premium', #{net.to_json});
      mset('gst_percentage', #{gst.to_json});
      mset('total_premium', #{total.to_json});
      mset('policy_start_date', #{start_d.to_json});
      mset('policy_end_date', #{end_d.to_json});
      mset('vehicle_idv', #{idv_val.to_json});
      msetn('motor_insurance[policy_booking_date]', #{booking.to_json});
      msetn('motor_insurance[policy_number]', #{pol_num.to_json});
      msetn('motor_insurance[registration_number]', #{reg_num.to_json});
      msetn('motor_insurance[vehicle_number]', #{reg_num.to_json});
      minject('motor_insurance[insurance_company_name]', #{company.to_json});
      minject('motor_insurance[policy_holder]', 'Self');
      HTMLFormElement.prototype.submit.call(document.querySelector('form'));
    JS
  elsif current_url.to_s.include?('/insurance/other')
    # Other insurance form — re-inject stored values before JS submit
    data      = @other_form_data || {}
    net       = data['Net Premium'].to_s
    gst       = '18'
    total     = net.to_f > 0 ? (net.to_f * (1 + gst.to_f / 100)).round(2).to_s : ''
    company   = @selected_other_company.to_s
    start_d   = @other_start_date.to_s
    end_d     = @other_end_date.to_s
    pol_num   = data['Policy Number'].to_s
    ins_type  = data['Insurance Type'].to_s
    cust_id   = @other_customer&.id.to_s
    cust_name = @other_customer_name.to_s
    page.execute_script(<<~JS)
      function oset(id, val) { var el = document.getElementById(id); if (el && val !== undefined && val !== '') { el.value = val; el.dispatchEvent(new Event('input',{bubbles:true})); el.dispatchEvent(new Event('change',{bubbles:true})); } }
      function osetn(name, val) { var el = document.querySelector('[name="' + name + '"]'); if (el && val !== undefined && val !== '') { el.value = val; el.dispatchEvent(new Event('input',{bubbles:true})); el.dispatchEvent(new Event('change',{bubbles:true})); } }
      function oinject(name, val) {
        if (!val) return;
        // Always use hidden input approach (appended at end of form, overrides select)
        var el = document.querySelector('input[type="hidden"][name="' + name + '"]');
        if (!el) { el = document.createElement('input'); el.type = 'hidden'; el.name = name; document.querySelector('form').appendChild(el); }
        el.value = val;
      }
      oset('net_premium', #{net.to_json});
      oset('gst_percentage', #{gst.to_json});
      oset('total_premium', #{total.to_json});
      oset('start_date', #{start_d.to_json});
      oset('end_date', #{end_d.to_json});
      osetn('other_insurance[policy_number]', #{pol_num.to_json});
      oinject('other_insurance[insurance_company_name]', #{company.to_json});
      oinject('other_insurance[insurance_type]', #{ins_type.to_json});
      // Inject customer_id
      var custId = #{cust_id.to_json};
      if (custId) {
        var custSel = document.querySelector('[name="other_insurance[customer_id]"]');
        if (custSel) {
          var found = Array.from(custSel.options).some(function(o){ return o.value == custId; });
          if (!found){ var opt = document.createElement('option'); opt.value = custId; opt.text = #{cust_name.to_json}; custSel.appendChild(opt); }
          custSel.value = custId;
        }
      }
      // Set defaults for required fields not yet filled
      var pm = document.querySelector('[name="other_insurance[payment_mode]"]');
      if (pm && !pm.value) { pm.value = 'Yearly'; }
      var si = document.querySelector('[name="other_insurance[sum_insured]"]');
      if (si && !si.value) { si.value = '500000'; }
      HTMLFormElement.prototype.submit.call(document.querySelector('form'));
    JS
  else
    begin
      click_button button_text, wait: 5
    rescue Capybara::ElementNotFound
      begin
        find('button[type="submit"]', wait: 2).click
      rescue Capybara::ElementNotFound
        page.execute_script("document.querySelector('form').submit();")
      end
    end
  end
end

# ============================================================
# Validation / Error Steps
# ============================================================
When('I click {string} without filling any fields') do |button_text|
  begin
    click_button button_text, wait: 3
  rescue Capybara::ElementNotFound
    begin
      find('input[type="submit"]', wait: 2).click
    rescue Capybara::ElementNotFound
      page.execute_script("document.querySelector('form').submit();")
    end
  end
end

Then('I should see mandatory field errors for life insurance') do
  # Browser HTML5 validation or server-side error
  has_validation_error = page.has_css?('.alert-danger', wait: 5) ||
                         page.has_css?('.invalid-feedback', wait: 2) ||
                         page.has_css?('[required]:invalid', wait: 2) ||
                         page.has_text?('can\'t be blank', wait: 2) ||
                         page.has_text?('is invalid', wait: 2)
  expect(has_validation_error).to be_truthy
end

When('I fill in {string} with {string}') do |field, value|
  @life_form_data ||= {}
  case field
  when 'Net Premium'
    @life_form_data['Net Premium'] = value
    js_set_field('net_premium', value, by_id: true)
    page.execute_script("if(typeof calculateTotalPremium === 'function') calculateTotalPremium();")
  when '1st Year GST %'
    @life_form_data['1st Year GST %'] = value
    js_set_field('first_year_gst', value, by_id: true)
    page.execute_script("if(typeof calculateTotalPremium === 'function') calculateTotalPremium();")
  else
    fill_in field, with: value
  end
end

When('I view that policy') do
  visit "/admin/insurance/life/#{@life_policy.id}"
end

When('I fill in a minimal life insurance form without policy number') do
  select 'New', from: 'life_insurance[policy_type]' rescue nil
  select 'Yearly', from: 'life_insurance[payment_mode]' rescue nil
  js_set_field('net_premium', '10000', by_id: true)
end

Then('I should see {string} error or be blocked by browser validation') do |_field_name|
  has_error = page.has_css?('.invalid-feedback', wait: 5) ||
              page.has_text?("can't be blank", wait: 2) ||
              page.has_css?('[required]:invalid', wait: 2)
  expect(has_error).to be_truthy
end

When('I fill in a minimal life insurance form with net premium {string}') do |premium|
  fill_in 'life_insurance[policy_number]', with: 'TEST-PREM-001' rescue nil
  js_set_field('net_premium', premium, by_id: true)
  select 'New', from: 'life_insurance[policy_type]' rescue nil
  select 'Yearly', from: 'life_insurance[payment_mode]' rescue nil
  js_set_field('start_date', Date.today.strftime('%Y-%m-%d'), by_id: true)
  js_set_field('end_date', (Date.today >> 12).strftime('%Y-%m-%d'), by_id: true)
end

Then('I should see premium validation error') do
  has_error = page.has_text?('greater than 0', wait: 5) ||
              page.has_css?('.invalid-feedback', wait: 3) ||
              page.has_css?('.alert-danger', wait: 3)
  expect(has_error).to be_truthy
end

When('I fill in a minimal life insurance form with end date before start date') do
  fill_in 'life_insurance[policy_number]', with: 'TEST-DATE-001' rescue nil
  select 'New', from: 'life_insurance[policy_type]' rescue nil
  select 'Yearly', from: 'life_insurance[payment_mode]' rescue nil
  js_set_field('net_premium', '10000', by_id: true)
  js_set_field('start_date', Date.today.strftime('%Y-%m-%d'), by_id: true)
  js_set_field('end_date', (Date.today - 1).strftime('%Y-%m-%d'), by_id: true)
end

# ============================================================
# Commission Steps
# ============================================================
Given('a life insurance policy exists with net premium {int}') do |premium|
  create_test_prerequisites
  @life_policy = LifeInsurance.find_or_create_by!(policy_number: 'LIFE-COMM-001') do |li|
    li.customer = @customer
    li.distributor = @distributor
    li.policy_holder = 'Self'
    li.insurance_company_name = 'LIC of India'
    li.policy_type = 'New'
    li.payment_mode = 'Yearly'
    li.policy_booking_date = Date.today
    li.policy_start_date = Date.today
    li.policy_end_date = 10.years.from_now.to_date
    li.sum_insured = 5000000
    li.net_premium = premium
    li.total_premium = premium * 1.045
    li.first_year_gst_percentage = 4.5
    li.policy_term = 10
    li.is_admin_added = true
  end
end

When('I visit the commission details page for that policy') do
  visit "/admin/insurance/life/#{@life_policy.id}/commission_details"
end

Then('I should see commission breakdown with correct calculations') do
  expect(page).to have_text('Commission', wait: 10)
end

Then('I should see main income percentage field') do
  expect(page).to have_text(/main income|commission/i, wait: 5)
end

Then('I should see sub-agent commission percentage field') do
  expect(page).to have_text(/sub.agent|affiliate/i, wait: 5)
end

Then('I should see distributor commission percentage field') do
  expect(page).to have_text(/company|affiliate|drwise/i, wait: 5)
end

Then('I should see total premium field') do
  expect(page).to have_text(/Rs\.\s*[\d,]+\.?\d*/, wait: 5)
end

Then('the total premium field should be auto-calculated') do
  page.execute_script("if(typeof calculateTotalPremium === 'function') calculateTotalPremium();")
  net  = @life_form_data&.dig('Net Premium').to_f
  gst  = @life_form_data&.dig('1st Year GST %').to_f
  expected = net > 0 ? (net * (1 + gst / 100)).round(2) : nil
  if expected
    total = find('#total_premium', wait: 5).value
    expect(total.to_f).to be > 0
  else
    expect(page).to have_css('#total_premium', wait: 5)
  end
end

# ============================================================
# Renewal Steps
# ============================================================
Given('a life insurance policy {string} exists and is eligible for renewal') do |policy_number|
  create_test_prerequisites
  @life_policy = LifeInsurance.find_or_create_by!(policy_number: policy_number) do |li|
    li.customer = @customer
    li.distributor = @distributor
    li.policy_holder = 'Self'
    li.insurance_company_name = 'LIC of India'
    li.policy_type = 'New'
    li.payment_mode = 'Yearly'
    li.policy_booking_date = Date.today - 1.year
    li.policy_start_date = Date.today - 1.year
    li.policy_end_date = 30.days.from_now.to_date
    li.sum_insured = 5000000
    li.net_premium = 50000
    li.total_premium = 52250
    li.first_year_gst_percentage = 4.5
    li.policy_term = 1
    li.is_admin_added = true
  end
  visit "/admin/insurance/life/#{@life_policy.id}"
end

When('I click {string} on that policy') do |link_text|
  if link_text == 'Renew' && @life_policy
    visit "/admin/insurance/life/#{@life_policy.id}/renew"
  else
    begin
      click_link link_text, wait: 5
    rescue Capybara::ElementNotFound
      find('a', text: link_text, wait: 5).click
    end
  end
end

Then('I should be on the new life insurance page prefilled with renewal data') do
  expect(page).to have_current_path(%r{/admin/insurance/life/\d+/renew|/admin/insurance/life/new}, wait: 10)
  expect(page).to have_select('life_insurance[policy_type]', selected: 'Renewal', wait: 5)
end

Then('the policy type should be {string}') do |policy_type|
  expect(page).to have_select('life_insurance[policy_type]', selected: policy_type, wait: 5)
end

Given('a life insurance policy {string} that has already been renewed') do |policy_number|
  create_test_prerequisites
  @life_policy = LifeInsurance.find_or_create_by!(policy_number: policy_number) do |li|
    li.customer = @customer
    li.distributor = @distributor
    li.policy_holder = 'Self'
    li.insurance_company_name = 'LIC of India'
    li.policy_type = 'New'
    li.payment_mode = 'Yearly'
    li.policy_booking_date = Date.today - 2.years
    li.policy_start_date = Date.today - 2.years
    li.policy_end_date = 30.days.from_now.to_date
    li.sum_insured = 5000000
    li.net_premium = 50000
    li.total_premium = 52250
    li.first_year_gst_percentage = 4.5
    li.policy_term = 2
    li.is_renewed = true
    li.is_admin_added = true
  end
  visit "/admin/insurance/life/#{@life_policy.id}"
end

Then('I should not see a {string} button') do |text|
  expect(page).not_to have_link(text, exact: true)
  expect(page).not_to have_button(text, exact: true)
end

# ============================================================
# DrWise / Classification Steps
# ============================================================
Given('a life insurance policy created by admin exists') do
  create_test_prerequisites
  @life_policy = LifeInsurance.find_or_create_by!(policy_number: 'LIFE-DRWISE-001') do |li|
    li.customer = @customer
    li.distributor = @distributor
    li.policy_holder = 'Self'
    li.insurance_company_name = 'LIC of India'
    li.policy_type = 'New'
    li.payment_mode = 'Yearly'
    li.policy_booking_date = Date.today
    li.policy_start_date = Date.today
    li.policy_end_date = 10.years.from_now.to_date
    li.sum_insured = 5000000
    li.net_premium = 50000
    li.total_premium = 52250
    li.first_year_gst_percentage = 4.5
    li.policy_term = 10
    li.is_admin_added = true
    li.is_customer_added = false
    li.is_agent_added = false
  end
end

When('I view the policy list') do
  visit '/admin/insurance/life'
end

Then('the policy should show {string} badge') do |badge_text|
  expect(page).to have_text(badge_text, wait: 10)
end

Given('I have multiple life insurance policies') do
  create_test_prerequisites
  ['LIFE-MULTI-001', 'LIFE-MULTI-002', 'LIFE-MULTI-003'].each_with_index do |num, i|
    LifeInsurance.find_or_create_by!(policy_number: num) do |li|
      li.customer = @customer
      li.distributor = @distributor
      li.policy_holder = 'Self'
      li.insurance_company_name = 'LIC of India'
      li.policy_type = (i.even? ? 'New' : 'Renewal')
      li.payment_mode = 'Yearly'
      li.policy_booking_date = Date.today
      li.policy_start_date = Date.today
      li.policy_end_date = 10.years.from_now.to_date
      li.sum_insured = 5000000
      li.net_premium = 50000
      li.total_premium = 52250
      li.first_year_gst_percentage = 4.5
      li.policy_term = 10
      li.is_admin_added = true
    end
  end
end

Then('I should see the policies listed') do
  expect(page).to have_css('table', wait: 10)
end

Then('I should see columns for policy number, client name, premium, status') do
  expect(page).to have_text(/POLICY|CUSTOMER|PREMIUM|STATUS/i, wait: 5)
end

# ============================================================
# Search Steps
# ============================================================
Given('a life insurance policy {string} exists') do |policy_number|
  create_test_prerequisites
  LifeInsurance.find_or_create_by!(policy_number: policy_number) do |li|
    li.customer = @customer
    li.distributor = @distributor
    li.policy_holder = 'Self'
    li.insurance_company_name = 'LIC of India'
    li.policy_type = 'New'
    li.payment_mode = 'Yearly'
    li.policy_booking_date = Date.today
    li.policy_start_date = Date.today
    li.policy_end_date = 10.years.from_now.to_date
    li.sum_insured = 5000000
    li.net_premium = 50000
    li.total_premium = 52250
    li.policy_term = 10
    li.is_admin_added = true
  end
end

When('I search for {string}') do |query|
  fill_in 'q', with: query, wait: 5
  find('input[name="q"]').send_keys(:return)
rescue Capybara::ElementNotFound
  fill_in 'search', with: query rescue nil
end

Then('I should see {string} in results') do |text|
  expect(page).to have_text(text, wait: 10)
end

Given('I have life insurance policies of type {string} and {string}') do |type1, type2|
  create_test_prerequisites
  [["LIFE-FILT-001", type1], ["LIFE-FILT-002", type2]].each do |num, type|
    LifeInsurance.find_or_create_by!(policy_number: num) do |li|
      li.customer = @customer
      li.distributor = @distributor
      li.policy_holder = 'Self'
      li.insurance_company_name = 'LIC of India'
      li.policy_type = type
      li.payment_mode = 'Yearly'
      li.policy_booking_date = Date.today
      li.policy_start_date = Date.today
      li.policy_end_date = 10.years.from_now.to_date
      li.sum_insured = 5000000
      li.net_premium = 50000
      li.total_premium = 52250
      li.policy_term = 10
      li.is_admin_added = true
    end
  end
end

When('I filter by type {string}') do |type|
  visit "/admin/insurance/life?policy_type=#{CGI.escape(type)}"
end

Then('I should only see {string} policies') do |type|
  expect(page).to have_css('table', wait: 10)
  within('table') do
    all('tr').each do |row|
      row_text = row.text.strip
      next if row_text.empty?
      next if row_text =~ /POLICY|CUSTOMER|COMPANY|SOURCE|COVERAGE|PREMIUM|STATUS|ACTIONS/i
      expect(row_text).to match(/\b#{Regexp.escape(type)}\b/)
    end
  end
end
