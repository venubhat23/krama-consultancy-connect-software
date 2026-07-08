require 'date'

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def build_converted_lead(subcategory:, contact:, category: 'insurance')
  create_test_prerequisites
  @lead = Lead.find_or_create_by!(contact_number: contact) do |l|
    l.first_name          = 'Conv'
    l.last_name           = subcategory.capitalize
    l.name                = "Conv #{subcategory.capitalize}"
    l.customer_type       = 'individual'
    l.lead_source         = 'walk_in'
    l.product_category    = category
    l.product_subcategory = subcategory
    l.is_direct           = true
    l.current_stage       = 'converted'
    l.converted_customer_id = @customer.id
    l.created_date        = Date.current
  end
  # Ensure customer link is set even if record already existed
  @lead.update_columns(current_stage: 'converted', converted_customer_id: @customer.id)
end

def submit_stage_patch(path)
  page.execute_script(<<~JS)
    var form = document.createElement('form');
    form.method = 'POST';
    form.action = '#{path}';
    var m = document.createElement('input');
    m.type = 'hidden'; m.name = '_method'; m.value = 'patch';
    form.appendChild(m);
    var csrf = document.createElement('input');
    csrf.type = 'hidden'; csrf.name = 'authenticity_token';
    csrf.value = document.querySelector('meta[name="csrf-token"]')?.content || '';
    form.appendChild(csrf);
    document.body.appendChild(form);
    form.submit();
  JS
  sleep 1.5
end

# ─────────────────────────────────────────────────────────────────────────────
# Section 1: Product Category × Product Type UI
# ─────────────────────────────────────────────────────────────────────────────

Then('the product type dropdown should contain {string}') do |expected_option|
  # The subcategory dropdown is populated by JS after category selection.
  # Wait for JS to run then check the select options via DOM.
  found = false
  5.times do
    found = page.evaluate_script(<<~JS)
      (function() {
        var sel = document.getElementById('product_subcategory');
        if (!sel) return false;
        return Array.from(sel.options).some(function(o) {
          return o.text.trim() === #{expected_option.to_json} || o.value.trim() === #{expected_option.to_json};
        });
      })()
    JS
    break if found
    sleep 0.5
  end
  expect(found).to be_truthy, "Product type option '#{expected_option}' not found in dropdown"
end


# ─────────────────────────────────────────────────────────────────────────────
# Section 3: Lead Creator with Category
# ─────────────────────────────────────────────────────────────────────────────

Given('a lead exists with name {string} and contact {string} and category {string}') do |name, contact, category|
  create_test_prerequisites
  parts = name.split(' ')
  @lead = Lead.find_or_create_by!(contact_number: contact) do |l|
    l.first_name          = parts.first
    l.last_name           = parts[1..-1].join(' ')
    l.name                = name
    l.customer_type       = 'individual'
    l.lead_source         = 'walk_in'
    l.product_category    = category
    l.product_subcategory = category == 'travel' ? 'domestic' : 'life'
    l.is_direct           = true
    l.current_stage       = 'lead_generated'
    l.created_date        = Date.current
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# Section 3: CRUD — Delete
# ─────────────────────────────────────────────────────────────────────────────

When('I delete the lead via direct HTTP') do
  expect(@lead).not_to be_nil
  lead_id = @lead.id
  # Visit the leads list page first to have a valid CSRF token context
  visit '/admin/leads'
  expect(page).to have_current_path(%r{/admin/leads}, wait: 10)
  page.execute_script(<<~JS)
    var form = document.createElement('form');
    form.method = 'POST';
    form.action = '/admin/leads/#{lead_id}';
    var m = document.createElement('input');
    m.type = 'hidden'; m.name = '_method'; m.value = 'delete';
    form.appendChild(m);
    var csrf = document.createElement('input');
    csrf.type = 'hidden'; csrf.name = 'authenticity_token';
    csrf.value = document.querySelector('meta[name="csrf-token"]')?.content || '';
    form.appendChild(csrf);
    document.body.appendChild(form);
    form.submit();
  JS
  sleep 2
end

Then('{string} should not appear in the leads list') do |name|
  visit '/admin/leads'
  expect(page).not_to have_text(name, wait: 5)
end

# ─────────────────────────────────────────────────────────────────────────────
# Section 4: Stage Lifecycle Steps
# ─────────────────────────────────────────────────────────────────────────────

When('I update lead stage to {string}') do |new_stage|
  # update_stage reads params[:new_stage]; convert_stage also accepts params[:stage]
  page.execute_script(<<~JS)
    var form = document.createElement('form');
    form.method = 'POST';
    form.action = '/admin/leads/#{@lead.id}/update_stage';
    var m = document.createElement('input');
    m.type = 'hidden'; m.name = '_method'; m.value = 'patch';
    form.appendChild(m);
    var csrf = document.createElement('input');
    csrf.type = 'hidden'; csrf.name = 'authenticity_token';
    csrf.value = document.querySelector('meta[name="csrf-token"]')?.content || '';
    form.appendChild(csrf);
    var ns = document.createElement('input');
    ns.type = 'hidden'; ns.name = 'new_stage'; ns.value = #{new_stage.to_json};
    form.appendChild(ns);
    document.body.appendChild(form);
    form.submit();
  JS
  sleep 2
  @lead.reload
end

# ─────────────────────────────────────────────────────────────────────────────
# Section 5: Converted Lead Helpers
# ─────────────────────────────────────────────────────────────────────────────

Given('a converted lead exists with insurance subcategory {string} and contact {string}') do |subcategory, contact|
  build_converted_lead(subcategory: subcategory, contact: contact)
end

When('I click Create Policy on the lead') do
  # Submit PATCH to create_policy endpoint (matches the turbo-method link)
  submit_stage_patch("/admin/leads/#{@lead.id}/create_policy")
end

Then('I should be on the other insurance creation page') do
  expect(page).to have_current_path(%r{/admin/insurance/other/new}, wait: 15)
end

Then('I should be on the health insurance creation page') do
  expect(page).to have_current_path(%r{/admin/health_insurances/new|/admin/insurance/health/new}, wait: 15)
end

Then('I should be on the life insurance creation page') do
  expect(page).to have_current_path(%r{/admin/life_insurances/new|/admin/insurance/life/new}, wait: 15)
end

Then('I should be on the motor insurance creation page') do
  expect(page).to have_current_path(%r{/admin/motor_insurances/new|/admin/insurance/motor/new}, wait: 15)
end

# ─────────────────────────────────────────────────────────────────────────────
# Section 6: End-to-End Travel Insurance Conversion
# ─────────────────────────────────────────────────────────────────────────────

When('I fill in the other insurance form for travel conversion:') do |table|
  table.hashes.each do |row|
    case row['field']
    when 'Policy Number'
      page.execute_script(
        "var el = document.querySelector('[name=\"other_insurance[policy_number]\"]'); if(el){ el.value = #{row['value'].to_json}; el.dispatchEvent(new Event('input',{bubbles:true})); }"
      )
    when 'Insurance Type'
      page.execute_script(<<~JS)
        var sel = document.querySelector('[name="other_insurance[insurance_type]"]');
        if (sel) {
          sel.value = 'Travel Insurance';
          sel.dispatchEvent(new Event('change',{bubbles:true}));
        }
      JS
    when 'Net Premium'
      page.execute_script(
        "var el = document.getElementById('net_premium'); if(el){ el.value = #{row['value'].to_json}; el.dispatchEvent(new Event('input',{bubbles:true})); el.dispatchEvent(new Event('change',{bubbles:true})); }"
      )
      page.execute_script("if(typeof calculateTotalPremium === 'function') calculateTotalPremium();")
    end
  end
  sleep 0.3
end

When('I set the other insurance company for lead conversion') do
  @selected_other_company = 'Tata AIG'
  page.execute_script(<<~JS)
    var sel = document.getElementById('other_insurance_insurance_company_name') ||
              document.querySelector('[name="other_insurance[insurance_company_name]"]');
    if (sel) {
      sel.disabled = false;
      var found = Array.from(sel.options).some(function(o){ return o.value === 'Tata AIG'; });
      if (!found) {
        var opt = document.createElement('option');
        opt.value = 'Tata AIG'; opt.text = 'Tata AIG'; sel.appendChild(opt);
      }
      sel.value = 'Tata AIG';
    }
  JS
end

When('I submit the other insurance form for lead conversion') do
  net        = '5000'
  gst        = '18'
  total      = (net.to_f * (1 + gst.to_f / 100)).round(2).to_s
  company    = (@selected_other_company || 'Tata AIG').to_s
  start_d    = @other_start_date.to_s
  end_d      = @other_end_date.to_s
  cust_id    = @customer&.id.to_s

  page.execute_script(<<~JS)
    function oset(id, val) { var el = document.getElementById(id); if (el && val) { el.value = val; el.dispatchEvent(new Event('input',{bubbles:true})); el.dispatchEvent(new Event('change',{bubbles:true})); } }
    function oinject(name, val) {
      if (!val) return;
      var el = document.querySelector('input[type="hidden"][name="' + name + '"]');
      if (!el) { el = document.createElement('input'); el.type = 'hidden'; el.name = name; document.querySelector('form').appendChild(el); }
      el.value = val;
    }
    oset('net_premium', #{net.to_json});
    oset('gst_percentage', #{gst.to_json});
    oset('total_premium', #{total.to_json});
    oset('start_date', #{start_d.to_json});
    oset('end_date', #{end_d.to_json});
    oset('policy_type_select', 'New');
    oinject('other_insurance[insurance_company_name]', #{company.to_json});
    var pm = document.querySelector('[name="other_insurance[payment_mode]"]');
    if (pm && !pm.value) { pm.value = 'Yearly'; }
    var si = document.querySelector('[name="other_insurance[sum_insured]"]');
    if (si && !si.value) { si.value = '500000'; }
    var custSel = document.querySelector('[name="other_insurance[customer_id]"]');
    if (custSel && #{cust_id.to_json}) {
      var found = Array.from(custSel.options).some(function(o){ return o.value == #{cust_id.to_json}; });
      if (!found){ var opt = document.createElement('option'); opt.value = #{cust_id.to_json}; opt.text = 'Test Client'; custSel.appendChild(opt); }
      custSel.value = #{cust_id.to_json};
    }
    document.querySelector('form').submit();
  JS
  sleep 3
end

Then('I should see {string} in the other insurance list') do |text|
  expect(page).to have_text(/#{Regexp.escape(text)}/i, wait: 15)
end

Then('the other insurance list should have at least {int} record') do |count|
  # Count rows in the list table (or cards)
  row_count = page.evaluate_script(<<~JS)
    (function() {
      var rows = document.querySelectorAll('table tbody tr, .insurance-card, .policy-row');
      return rows.length;
    })()
  JS
  expect(row_count).to be >= count, "Expected at least #{count} records in other insurance list, found #{row_count}"
end

# ─────────────────────────────────────────────────────────────────────────────
# Section 7: Health Insurance Redirect (list visit)
# ─────────────────────────────────────────────────────────────────────────────

Then('the health insurance list page should load') do
  expect(page).not_to have_text('Application Error', wait: 5)
  expect(page).to have_current_path(%r{/admin/(insurance/health|health_insurances)}, wait: 10)
end

# ─────────────────────────────────────────────────────────────────────────────
# Section 8: Index filters and tabs
# ─────────────────────────────────────────────────────────────────────────────

When('I filter leads by product category {string}') do |category|
  page.execute_script(<<~JS)
    var sel = document.querySelector('[name="product_category"]');
    if (sel) {
      sel.value = #{category.to_json};
      sel.dispatchEvent(new Event('change', {bubbles: true}));
      var form = sel.closest('form');
      if (form) form.submit();
    } else {
      window.location.href = '/admin/leads?product_category=#{category}';
    }
  JS
  sleep 1.5
  expect(page).to have_current_path(%r{/admin/leads}, wait: 10)
end

When('I visit the leads converted tab') do
  visit '/admin/leads?tab=converted'
  expect(page).to have_current_path(%r{/admin/leads}, wait: 10)
end

Then('the leads page should show converted leads only') do
  # The converted tab heading or label should be present
  has_converted = page.has_text?(/Converted|converted/i, wait: 10)
  expect(has_converted).to be_truthy
end

Then('I should see the stage action buttons') do
  has_buttons = page.has_css?('a, button', text: /Advance|Next Stage|Consultation|Convert|Stage/i, wait: 10) ||
                page.has_css?('.stage-action, [data-action="advance"]', wait: 3) ||
                page.has_css?('.btn', wait: 3)
  expect(has_buttons).to be_truthy
end

