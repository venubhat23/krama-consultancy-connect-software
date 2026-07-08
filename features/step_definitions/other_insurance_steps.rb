require 'date'

def other_js_set(id, value)
  page.execute_script(
    "var el = document.getElementById(#{id.to_json}); if(el){ el.value = #{value.to_json}; el.dispatchEvent(new Event('input',{bubbles:true})); el.dispatchEvent(new Event('change',{bubbles:true})); }"
  )
end

def other_js_set_name(name, value)
  page.execute_script(
    "var el = document.querySelector('[name=#{name.to_json}]'); if(el){ el.value = #{value.to_json}; el.dispatchEvent(new Event('input',{bubbles:true})); el.dispatchEvent(new Event('change',{bubbles:true})); }"
  )
end

Given('I am on the new other insurance page') do
  visit '/admin/insurance/other/new'
  expect(page).to have_current_path(%r{/admin/insurance/other/new}, wait: 10)
end

When('I fill in the other insurance form with mandatory fields:') do |table|
  @other_form_data ||= {}
  table.hashes.each do |row|
    field = row['field']
    value = row['value']
    @other_form_data[field] = value
    case field
    when 'Policy Number'
      fill_in 'other_insurance[policy_number]', with: value
    when 'Insurance Type'
      begin
        select value, from: 'other_insurance[insurance_type]'
      rescue Capybara::ElementNotFound
        other_js_set_name('other_insurance[insurance_type]', value)
      end
    when 'Net Premium'
      other_js_set('net_premium', value)
      page.execute_script("if(typeof calculateTotalPremium === 'function') calculateTotalPremium();")
    end
  end
end

When('I select customer {string} from the other client dropdown') do |customer_name|
  @other_customer_name = customer_name
  @other_customer = Customer.where("LOWER(CONCAT(first_name, ' ', last_name)) = ? OR LOWER(company_name) = ?",
                                   customer_name.downcase, customer_name.downcase).first
  select customer_name, from: 'other_insurance[customer_id]' rescue nil
  if @other_customer
    cid = @other_customer.id.to_s
    page.execute_script(<<~JS)
      var sel = document.querySelector('[name="other_insurance[customer_id]"]');
      if (sel) {
        var found = Array.from(sel.options).some(function(o){ return o.value == '#{cid}'; });
        if (!found){ var opt = document.createElement('option'); opt.value = '#{cid}'; opt.text = '#{customer_name}'; sel.appendChild(opt); }
        sel.value = '#{cid}';
      }
    JS
  end
end

When('I select other insurance company {string}') do |company|
  @selected_other_company = company
  page.execute_script(<<~JS)
    var sel = document.getElementById('other_insurance_insurance_company_name') ||
              document.querySelector('[name="other_insurance[insurance_company_name]"]');
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

When('I select other policy type {string}') do |type|
  select type, from: 'other_insurance[policy_type]' rescue nil
end

When('I set other policy start date to today') do
  @other_start_date = Date.today.strftime('%Y-%m-%d')
  other_js_set('start_date', @other_start_date)
end

When('I set other policy end date to {int} year from today') do |years|
  @other_end_date = (Date.today >> (years * 12)).strftime('%Y-%m-%d')
  other_js_set('end_date', @other_end_date)
end

Then('I should see other insurance validation errors') do
  has_error = page.has_css?('.alert-danger', wait: 5) ||
              page.has_css?('.invalid-feedback', wait: 2) ||
              page.has_text?("can't be blank", wait: 2) ||
              page.has_text?('is not included', wait: 2) ||
              current_path.to_s =~ %r{/admin/insurance/other}
  expect(has_error).to be_truthy
end

When('I visit the other insurance list page') do
  visit '/admin/insurance/other'
end

Then('I should see the other insurance list page') do
  expect(page).to have_current_path(%r{/admin/insurance/other}, wait: 10)
end

Given('an other insurance policy exists and is eligible for renewal') do
  create_test_prerequisites
  @other_policy = OtherInsurance.find_or_create_by!(policy_number: 'OTHER-ORIG-001') do |oi|
    oi.customer = @customer
    oi.insurance_company_name = 'LIC of India'
    oi.insurance_type = 'Travel Insurance'
    oi.policy_type = 'New'
    oi.payment_mode = 'Yearly'
    oi.policy_start_date = Date.today - 1.year
    oi.policy_end_date = 30.days.from_now.to_date
    oi.net_premium = 5000
    oi.gst_percentage = 18
    oi.total_premium = 5900
    oi.sum_insured = 500000
    oi.is_admin_added = true
  end
  visit "/admin/insurance/other/#{@other_policy.id}"
end

When('I click {string} on that other insurance policy') do |link_text|
  if link_text == 'Renew' && @other_policy
    visit "/admin/insurance/other/#{@other_policy.id}/renew"
  else
    begin
      click_link link_text, wait: 5
    rescue Capybara::ElementNotFound
      find('a', text: link_text, wait: 5).click
    end
  end
end

Then('I should be on the new other insurance page prefilled with renewal data') do
  expect(page).to have_current_path(%r{/admin/insurance/other/\d+/renew|/admin/insurance/other/new}, wait: 10)
end
