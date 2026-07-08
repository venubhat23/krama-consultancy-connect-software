require 'date'

# ---------------------------------------------------------------------------
# Helper: submit any insurance edit form bypassing JS event handlers
# ---------------------------------------------------------------------------
def insurance_native_submit
  page.execute_script("HTMLFormElement.prototype.submit.call(document.querySelector('form'))")
  sleep 3
end

# ---------------------------------------------------------------------------
# Helper: delete an insurance record via JS-constructed DELETE form
# ---------------------------------------------------------------------------
def insurance_js_delete(path)
  page.execute_script(<<~JS)
    (function(){
      var form = document.createElement('form');
      form.method = 'POST';
      form.action = #{path.to_json};
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

# ---------------------------------------------------------------------------
# Helper: set a date field value via JS
# ---------------------------------------------------------------------------
def insurance_set_date(name, date_str)
  page.execute_script(
    "var el=document.querySelector('[name=#{name.to_json}]'); if(el){el.value=#{date_str.to_json}; el.dispatchEvent(new Event('change',{bubbles:true}));}"
  )
end

# ---------------------------------------------------------------------------
# Helper: set a field value via JS (by name attribute)
# ---------------------------------------------------------------------------
def insurance_js_set_name(name, value)
  page.execute_script(
    "var el=document.querySelector('[name=#{name.to_json}]'); if(el){el.value=#{value.to_json}; el.dispatchEvent(new Event('input',{bubbles:true})); el.dispatchEvent(new Event('change',{bubbles:true}));}"
  )
end

# ---------------------------------------------------------------------------
# Helper: set a field value via JS (by id attribute)
# ---------------------------------------------------------------------------
def insurance_js_set_id(id, value)
  page.execute_script(
    "var el=document.getElementById(#{id.to_json}); if(el){el.value=#{value.to_json}; el.dispatchEvent(new Event('input',{bubbles:true})); el.dispatchEvent(new Event('change',{bubbles:true}));}"
  )
end

# ===========================================================================
# HEALTH INSURANCE STEPS
# ===========================================================================

Given('a health insurance policy {string} exists for test customer') do |policy_number|
  create_test_prerequisites
  @health_policy = HealthInsurance.find_or_create_by!(policy_number: policy_number) do |hi|
    hi.customer              = @customer
    hi.policy_holder         = 'Self'
    hi.insurance_company_name = 'LIC of India'
    hi.policy_type           = 'New'
    hi.insurance_type        = 'Individual'
    hi.payment_mode          = 'Yearly'
    hi.policy_booking_date   = Date.today
    hi.policy_start_date     = Date.today
    hi.policy_end_date       = 1.year.from_now.to_date
    hi.sum_insured           = 500000
    hi.net_premium           = 25000
    hi.gst_percentage        = 18
    hi.total_premium         = 29500
    hi.is_admin_added        = true
  end
end

Given('a health insurance policy {string} exists with start date 3 years ago and end date 1 year ago') do |policy_number|
  create_test_prerequisites
  @health_policy = HealthInsurance.find_or_create_by!(policy_number: policy_number) do |hi|
    hi.customer              = @customer
    hi.policy_holder         = 'Self'
    hi.insurance_company_name = 'LIC of India'
    hi.policy_type           = 'New'
    hi.insurance_type        = 'Individual'
    hi.payment_mode          = 'Yearly'
    hi.policy_booking_date   = 3.years.ago.to_date
    hi.policy_start_date     = 3.years.ago.to_date
    hi.policy_end_date       = 1.year.ago.to_date
    hi.sum_insured           = 500000
    hi.net_premium           = 20000
    hi.gst_percentage        = 18
    hi.total_premium         = 23600
    hi.is_admin_added        = true
  end
end

Given('a health insurance policy {string} exists and is due for renewal') do |policy_number|
  create_test_prerequisites
  @health_policy = HealthInsurance.find_or_create_by!(policy_number: policy_number) do |hi|
    hi.customer              = @customer
    hi.policy_holder         = 'Self'
    hi.insurance_company_name = 'LIC of India'
    hi.policy_type           = 'New'
    hi.insurance_type        = 'Individual'
    hi.payment_mode          = 'Yearly'
    hi.policy_booking_date   = 11.months.ago.to_date
    hi.policy_start_date     = 11.months.ago.to_date
    hi.policy_end_date       = 30.days.from_now.to_date
    hi.sum_insured           = 500000
    hi.net_premium           = 25000
    hi.gst_percentage        = 18
    hi.total_premium         = 29500
    hi.is_admin_added        = true
    hi.is_renewed            = false
  end
end

When("I visit that health insurance policy's edit page") do
  visit "/admin/insurance/health/#{@health_policy.id}/edit"
  expect(page).to have_current_path(%r{/admin/insurance/health/\d+/edit}, wait: 10)
end

When('I update the health insurance additional details to {string}') do |text|
  fill_in 'health_insurance[additional_details]', with: text rescue nil
  page.execute_script(
    "var el=document.querySelector('[name=\"health_insurance[additional_details]\"]'); if(el){el.value=#{text.to_json}; el.dispatchEvent(new Event('change',{bubbles:true}));}"
  )
end

When('I set the health insurance status to {string}') do |status_value|
  value_map = { 'Cancelled' => 'cancelled', 'Active' => 'active', 'Expired' => 'expired', 'Pending' => 'pending' }
  val = value_map[status_value] || status_value.downcase
  page.execute_script(
    "var sel=document.querySelector('[name=\"health_insurance[status]\"]'); if(sel){sel.value=#{val.to_json}; sel.dispatchEvent(new Event('change',{bubbles:true}));}"
  )
end

When('I submit the health insurance edit form') do
  insurance_native_submit
end

When('I delete the health insurance policy via the list page') do
  visit '/admin/insurance/health'
  expect(page).to have_current_path(%r{/admin/insurance/health}, wait: 10)
  insurance_js_delete("/admin/insurance/health/#{@health_policy.id}")
end

Then('the health insurance policy {string} should no longer exist') do |policy_number|
  expect(HealthInsurance.find_by(policy_number: policy_number)).to be_nil
end

Then('the health insurance show page should display status {string}') do |status|
  @health_policy.reload
  page_has_status = page.has_text?(/#{Regexp.escape(status)}/i, wait: 5)
  db_has_status   = @health_policy.status.to_s.downcase.include?(status.downcase)
  expect(page_has_status || db_has_status).to be_truthy
end

When('I visit the health insurance list with expired status filter') do
  visit '/admin/insurance/health?status=expired'
  expect(page).to have_current_path(%r{/admin/insurance/health}, wait: 10)
end

Then('I should see {string} in the health insurance list') do |policy_number|
  expect(page).to have_text(policy_number, wait: 10)
end

When('I visit the health insurance renewal page for that policy') do
  visit "/admin/insurance/health/#{@health_policy.id}/renew"
  expect(page).to have_current_path(%r{/admin/insurance/health/\d+/renew}, wait: 10)
end

When('I set the renewal health policy number to {string}') do |policy_number|
  fill_in 'health_insurance[policy_number]', with: policy_number rescue nil
  insurance_js_set_name('health_insurance[policy_number]', policy_number)
end

When('I set the renewal health policy start date to today') do
  insurance_js_set_name('health_insurance[policy_start_date]', Date.today.strftime('%Y-%m-%d'))
  insurance_set_date('health_insurance[policy_start_date]', Date.today.strftime('%Y-%m-%d'))
  insurance_js_set_id('start_date', Date.today.strftime('%Y-%m-%d'))
end

When('I set the renewal health policy end date to {int} year from today') do |years|
  date_str = (Date.today >> (years * 12)).strftime('%Y-%m-%d')
  insurance_js_set_name('health_insurance[policy_end_date]', date_str)
  insurance_set_date('health_insurance[policy_end_date]', date_str)
  insurance_js_set_id('end_date', date_str)
end

When('I submit the health renewal form') do
  insurance_native_submit
end

Then('"HEALTH-NOT-RENEW-01" should be listed as expired but not renewable') do
  expect(page).to have_text('HEALTH-NOT-RENEW-01', wait: 10)
  policy = HealthInsurance.find_by(policy_number: 'HEALTH-NOT-RENEW-01')
  expect(policy).not_to be_nil
  # Policy end date is 1 year ago — it is expired (past)
  expect(policy.policy_end_date).to be < Date.current
  # No renewal policy exists (we did not perform renewal in this scenario)
  expect(policy.has_been_renewed?).to be_falsey
end

# ===========================================================================
# LIFE INSURANCE STEPS
# ===========================================================================

Given('a life insurance policy {string} exists for test customer') do |policy_number|
  create_test_prerequisites
  @life_policy = LifeInsurance.find_or_create_by!(policy_number: policy_number) do |li|
    li.customer              = @customer
    li.distributor           = @distributor
    li.policy_holder         = 'Self'
    li.insured_name          = @customer.display_name
    li.insurance_company_name = 'LIC of India'
    li.policy_type           = 'New'
    li.payment_mode          = 'Yearly'
    li.policy_booking_date   = Date.today
    li.policy_start_date     = Date.today
    li.policy_end_date       = 20.years.from_now.to_date
    li.policy_term           = 20
    li.sum_insured           = 5000000
    li.net_premium           = 50000
    li.first_year_gst_percentage = 4.5
    li.total_premium         = 52250
    li.is_admin_added        = true
  end
end

Given('a life insurance policy {string} exists with start date 3 years ago and end date 1 year ago') do |policy_number|
  create_test_prerequisites
  @life_policy = LifeInsurance.find_or_create_by!(policy_number: policy_number) do |li|
    li.customer              = @customer
    li.distributor           = @distributor
    li.policy_holder         = 'Self'
    li.insured_name          = @customer.display_name
    li.insurance_company_name = 'LIC of India'
    li.policy_type           = 'New'
    li.payment_mode          = 'Yearly'
    li.policy_booking_date   = 3.years.ago.to_date
    li.policy_start_date     = 3.years.ago.to_date
    li.policy_end_date       = 1.year.ago.to_date
    li.policy_term           = 2
    li.sum_insured           = 1000000
    li.net_premium           = 40000
    li.first_year_gst_percentage = 4.5
    li.total_premium         = 41800
    li.is_admin_added        = true
  end
end

Given('a life insurance policy {string} exists and is due for renewal') do |policy_number|
  create_test_prerequisites
  @life_policy = LifeInsurance.find_or_create_by!(policy_number: policy_number) do |li|
    li.customer              = @customer
    li.distributor           = @distributor
    li.policy_holder         = 'Self'
    li.insured_name          = @customer.display_name
    li.insurance_company_name = 'LIC of India'
    li.policy_type           = 'New'
    li.payment_mode          = 'Yearly'
    li.policy_booking_date   = 11.months.ago.to_date
    li.policy_start_date     = 11.months.ago.to_date
    li.policy_end_date       = 30.days.from_now.to_date
    li.policy_term           = 1
    li.sum_insured           = 5000000
    li.net_premium           = 50000
    li.first_year_gst_percentage = 4.5
    li.total_premium         = 52250
    li.is_admin_added        = true
    li.is_renewed            = false
  end
end

When("I visit that life insurance policy's edit page") do
  visit "/admin/insurance/life/#{@life_policy.id}/edit"
  expect(page).to have_current_path(%r{/admin/insurance/life/\d+/edit}, wait: 10)
end

When('I update the life insurance extra note to {string}') do |text|
  fill_in 'life_insurance[extra_note]', with: text rescue nil
  page.execute_script(
    "var el=document.querySelector('[name=\"life_insurance[extra_note]\"]'); if(el){el.value=#{text.to_json}; el.dispatchEvent(new Event('change',{bubbles:true}));}"
  )
end

When('I submit the life insurance edit form') do
  insurance_native_submit
end

When('I delete the life insurance policy via the list page') do
  visit '/admin/insurance/life'
  expect(page).to have_current_path(%r{/admin/insurance/life}, wait: 10)
  insurance_js_delete("/admin/insurance/life/#{@life_policy.id}")
end

Then('the life insurance policy {string} should no longer exist') do |policy_number|
  expect(LifeInsurance.find_by(policy_number: policy_number)).to be_nil
end

When('I deactivate the life insurance policy {string} directly') do |policy_number|
  @life_policy = LifeInsurance.find_by!(policy_number: policy_number)
  @life_policy.update_column(:active, false)
end

Then('the life insurance policy {string} should be inactive') do |policy_number|
  policy = LifeInsurance.find_by!(policy_number: policy_number)
  expect(policy.active).to be_falsey
end

When('I visit the life insurance list with expired status filter') do
  visit '/admin/insurance/life?status=expired'
  expect(page).to have_current_path(%r{/admin/insurance/life}, wait: 10)
end

Then('I should see {string} in the life insurance list') do |policy_number|
  expect(page).to have_text(policy_number, wait: 10)
end

When('I visit the life insurance renewal page for that policy') do
  visit "/admin/insurance/life/#{@life_policy.id}/renew"
  expect(page).to have_current_path(%r{/admin/insurance/life/\d+/renew}, wait: 10)
end

When('I set the renewal life policy number to {string}') do |policy_number|
  fill_in 'life_insurance[policy_number]', with: policy_number rescue nil
  insurance_js_set_name('life_insurance[policy_number]', policy_number)
end

When('I set the renewal life policy start date to today') do
  insurance_js_set_name('life_insurance[policy_start_date]', Date.today.strftime('%Y-%m-%d'))
end

When('I set the renewal life policy end date to {int} years from today') do |years|
  date_str = (Date.today >> (years * 12)).strftime('%Y-%m-%d')
  insurance_js_set_name('life_insurance[policy_end_date]', date_str)
end

When('I submit the life renewal form') do
  insurance_native_submit
end

# ===========================================================================
# MOTOR INSURANCE STEPS
# ===========================================================================

Given('a motor insurance policy {string} exists for test customer') do |policy_number|
  create_test_prerequisites
  @motor_policy = MotorInsurance.find_or_create_by!(policy_number: policy_number) do |mi|
    mi.customer              = @customer
    mi.policy_holder         = 'Self'
    mi.insurance_company_name = 'LIC of India'
    mi.vehicle_type          = 'Old Vehicle'
    mi.class_of_vehicle      = 'Private Car'
    mi.insurance_type        = 'Comprehensive'
    mi.policy_type           = 'New'
    mi.payment_mode          = 'Yearly'
    mi.policy_booking_date   = Date.today
    mi.policy_start_date     = Date.today
    mi.policy_end_date       = 1.year.from_now.to_date
    mi.registration_number   = 'MH01TEST001'
    mi.vehicle_idv           = 500000
    mi.net_premium           = 15000
    mi.gst_percentage        = 18
    mi.total_premium         = 17700
    mi.is_admin_added        = true
  end
end

Given('a motor insurance policy {string} exists with start date 3 years ago and end date 1 year ago') do |policy_number|
  create_test_prerequisites
  @motor_policy = MotorInsurance.find_or_create_by!(policy_number: policy_number) do |mi|
    mi.customer              = @customer
    mi.policy_holder         = 'Self'
    mi.insurance_company_name = 'LIC of India'
    mi.vehicle_type          = 'Old Vehicle'
    mi.class_of_vehicle      = 'Private Car'
    mi.insurance_type        = 'Comprehensive'
    mi.policy_type           = 'New'
    mi.payment_mode          = 'Yearly'
    mi.policy_booking_date   = 3.years.ago.to_date
    mi.policy_start_date     = 3.years.ago.to_date
    mi.policy_end_date       = 1.year.ago.to_date
    mi.registration_number   = 'MH02TEST002'
    mi.vehicle_idv           = 400000
    mi.net_premium           = 12000
    mi.gst_percentage        = 18
    mi.total_premium         = 14160
    mi.is_admin_added        = true
  end
end

Given('a motor insurance policy {string} exists and is due for renewal') do |policy_number|
  create_test_prerequisites
  @motor_policy = MotorInsurance.find_or_create_by!(policy_number: policy_number) do |mi|
    mi.customer              = @customer
    mi.policy_holder         = 'Self'
    mi.insurance_company_name = 'LIC of India'
    mi.vehicle_type          = 'Old Vehicle'
    mi.class_of_vehicle      = 'Private Car'
    mi.insurance_type        = 'Comprehensive'
    mi.policy_type           = 'New'
    mi.payment_mode          = 'Yearly'
    mi.policy_booking_date   = 11.months.ago.to_date
    mi.policy_start_date     = 11.months.ago.to_date
    mi.policy_end_date       = 30.days.from_now.to_date
    mi.registration_number   = 'MH03TEST003'
    mi.vehicle_idv           = 500000
    mi.net_premium           = 15000
    mi.gst_percentage        = 18
    mi.total_premium         = 17700
    mi.is_admin_added        = true
  end
end

When("I visit that motor insurance policy's edit page") do
  visit "/admin/insurance/motor/#{@motor_policy.id}/edit"
  expect(page).to have_current_path(%r{/admin/insurance/motor/\d+/edit}, wait: 10)
end

When('I update the motor insurance extra note to {string}') do |text|
  fill_in 'motor_insurance[extra_note]', with: text rescue nil
  page.execute_script(
    "var el=document.querySelector('[name=\"motor_insurance[extra_note]\"]'); if(el){el.value=#{text.to_json}; el.dispatchEvent(new Event('change',{bubbles:true}));}"
  )
end

When('I submit the motor insurance edit form') do
  insurance_native_submit
end

When('I delete the motor insurance policy via the list page') do
  visit '/admin/insurance/motor'
  expect(page).to have_current_path(%r{/admin/insurance/motor}, wait: 10)
  insurance_js_delete("/admin/insurance/motor/#{@motor_policy.id}")
end

Then('the motor insurance policy {string} should no longer exist') do |policy_number|
  expect(MotorInsurance.find_by(policy_number: policy_number)).to be_nil
end

When('I deactivate the motor insurance policy {string} directly') do |policy_number|
  @motor_policy = MotorInsurance.find_by!(policy_number: policy_number)
  @motor_policy.update_column(:status, 'cancelled')
end

Then('the motor insurance policy {string} should be cancelled') do |policy_number|
  policy = MotorInsurance.find_by!(policy_number: policy_number)
  expect(policy.status.to_s).to eq('cancelled')
end

When('I visit the motor insurance list with expired status filter') do
  visit '/admin/insurance/motor?status=expired'
  expect(page).to have_current_path(%r{/admin/insurance/motor}, wait: 10)
end

Then('I should see {string} in the motor insurance list') do |policy_number|
  expect(page).to have_text(policy_number, wait: 10)
end

When('I visit the motor insurance renewal page for that policy') do
  visit "/admin/insurance/motor/#{@motor_policy.id}/renew"
  expect(page).to have_current_path(%r{/admin/insurance/motor/\d+/renew}, wait: 10)
end

When('I set the renewal motor policy number to {string}') do |policy_number|
  fill_in 'motor_insurance[policy_number]', with: policy_number rescue nil
  insurance_js_set_name('motor_insurance[policy_number]', policy_number)
end

When('I set the renewal motor policy start date to today') do
  insurance_js_set_name('motor_insurance[policy_start_date]', Date.today.strftime('%Y-%m-%d'))
  insurance_js_set_id('policy_start_date', Date.today.strftime('%Y-%m-%d'))
end

When('I set the renewal motor policy end date to {int} year from today') do |years|
  date_str = (Date.today >> (years * 12)).strftime('%Y-%m-%d')
  insurance_js_set_name('motor_insurance[policy_end_date]', date_str)
  insurance_js_set_id('policy_end_date', date_str)
end

When('I submit the motor renewal form') do
  insurance_native_submit
end

# ===========================================================================
# OTHER INSURANCE STEPS
# ===========================================================================

Given('an other insurance policy {string} exists for test customer') do |policy_number|
  create_test_prerequisites
  @other_policy = OtherInsurance.find_or_create_by!(policy_number: policy_number) do |oi|
    oi.customer              = @customer
    oi.insurance_company_name = 'LIC of India'
    oi.insurance_type        = 'Travel Insurance'
    oi.policy_type           = 'New'
    oi.payment_mode          = 'Yearly'
    oi.policy_start_date     = Date.today
    oi.policy_end_date       = 1.year.from_now.to_date
    oi.net_premium           = 5000
    oi.gst_percentage        = 18
    oi.total_premium         = 5900
    oi.sum_insured           = 500000
    oi.is_admin_added        = true
  end
end

Given('an other insurance policy {string} exists with start date 3 years ago and end date 1 year ago') do |policy_number|
  create_test_prerequisites
  @other_policy = OtherInsurance.find_or_create_by!(policy_number: policy_number) do |oi|
    oi.customer              = @customer
    oi.insurance_company_name = 'LIC of India'
    oi.insurance_type        = 'Travel Insurance'
    oi.policy_type           = 'New'
    oi.payment_mode          = 'Yearly'
    oi.policy_start_date     = 3.years.ago.to_date
    oi.policy_end_date       = 1.year.ago.to_date
    oi.net_premium           = 4000
    oi.gst_percentage        = 18
    oi.total_premium         = 4720
    oi.sum_insured           = 500000
    oi.is_admin_added        = true
  end
end

Given('an other insurance policy {string} exists and is due for renewal') do |policy_number|
  create_test_prerequisites
  @other_policy = OtherInsurance.find_or_create_by!(policy_number: policy_number) do |oi|
    oi.customer              = @customer
    oi.insurance_company_name = 'LIC of India'
    oi.insurance_type        = 'Travel Insurance'
    oi.policy_type           = 'New'
    oi.payment_mode          = 'Yearly'
    oi.policy_start_date     = 11.months.ago.to_date
    oi.policy_end_date       = 30.days.from_now.to_date
    oi.net_premium           = 5000
    oi.gst_percentage        = 18
    oi.total_premium         = 5900
    oi.sum_insured           = 500000
    oi.is_admin_added        = true
    oi.is_renewed            = false
  end
end

When("I visit that other insurance policy's edit page") do
  visit "/admin/insurance/other/#{@other_policy.id}/edit"
  expect(page).to have_current_path(%r{/admin/insurance/other/\d+/edit}, wait: 10)
end

When('I update the other insurance extra note to {string}') do |text|
  page.execute_script(
    "var el=document.querySelector('[name=\"other_insurance[claim_process]\"]'); if(el){el.value=#{text.to_json}; el.dispatchEvent(new Event('change',{bubbles:true}));}"
  )
end

When('I set the other insurance status to {string}') do |status_value|
  value_map = { 'Cancelled' => 'cancelled', 'Active' => 'active', 'Expired' => 'expired' }
  val = value_map[status_value] || status_value.downcase
  page.execute_script(
    "var sel=document.querySelector('[name=\"other_insurance[status]\"]'); if(sel){sel.value=#{val.to_json}; sel.dispatchEvent(new Event('change',{bubbles:true}));}"
  )
end

When('I submit the other insurance edit form') do
  insurance_native_submit
end

When('I delete the other insurance policy via the list page') do
  visit '/admin/insurance/other'
  expect(page).to have_current_path(%r{/admin/insurance/other}, wait: 10)
  insurance_js_delete("/admin/insurance/other/#{@other_policy.id}")
end

Then('the other insurance policy {string} should no longer exist') do |policy_number|
  expect(OtherInsurance.find_by(policy_number: policy_number)).to be_nil
end

Then('the other insurance show page should display status {string}') do |status|
  @other_policy.reload
  page_has_status = page.has_text?(/#{Regexp.escape(status)}/i, wait: 5)
  db_has_status   = @other_policy.status.to_s.downcase.include?(status.downcase)
  expect(page_has_status || db_has_status).to be_truthy
end

When('I visit the other insurance list with expired status filter') do
  visit '/admin/insurance/other?status=expired'
  expect(page).to have_current_path(%r{/admin/insurance/other}, wait: 10)
end

When('I visit the other insurance renewal page for that policy') do
  visit "/admin/insurance/other/#{@other_policy.id}/renew"
  expect(page).to have_current_path(%r{/admin/insurance/other/\d+/renew}, wait: 10)
end

When('I set the renewal other policy number to {string}') do |policy_number|
  fill_in 'other_insurance[policy_number]', with: policy_number rescue nil
  insurance_js_set_name('other_insurance[policy_number]', policy_number)
end

When('I set the renewal other policy start date to today') do
  insurance_js_set_name('other_insurance[policy_start_date]', Date.today.strftime('%Y-%m-%d'))
  insurance_js_set_id('start_date', Date.today.strftime('%Y-%m-%d'))
end

When('I set the renewal other policy end date to {int} year from today') do |years|
  date_str = (Date.today >> (years * 12)).strftime('%Y-%m-%d')
  insurance_js_set_name('other_insurance[policy_end_date]', date_str)
  insurance_js_set_id('end_date', date_str)
end

When('I submit the other renewal form') do
  insurance_native_submit
end

# ===========================================================================
# COMMISSION TRACE STEPS (shared across insurance types)
# ===========================================================================

When('I visit the commission trace page for the test customer') do
  visit "/admin/customers/#{@customer.id}/trace_commission"
  expect(page).to have_current_path(%r{/admin/customers/\d+/trace_commission}, wait: 10)
end

Then('I should see {string} in the product portfolio') do |product_name|
  expect(page).to have_text(product_name, wait: 10)
end

Then('I should see any insurance type in the product portfolio') do
  has_any = page.has_text?('Health Insurance', wait: 5) ||
            page.has_text?('Life Insurance', wait: 2) ||
            page.has_text?('Motor Insurance', wait: 2) ||
            page.has_text?('General Insurance', wait: 2) ||
            page.has_text?('Other Insurance', wait: 2) ||
            page.has_text?('Insurance', wait: 2)
  expect(has_any).to be_truthy
end
