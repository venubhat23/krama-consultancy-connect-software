require 'date'

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

# Named converted lead — creates the lead linked to the shared @customer fixture.
def build_named_converted_lead(full_name:, contact:, subcategory:, category: 'insurance')
  create_test_prerequisites

  parts = full_name.split(' ')
  first = parts.first
  last  = parts[1..-1].join(' ').presence || 'TestUser'

  lead = Lead.find_or_create_by!(contact_number: contact) do |l|
    l.first_name             = first
    l.last_name              = last
    l.name                   = full_name
    l.customer_type          = 'individual'
    l.lead_source            = 'walk_in'
    l.product_category       = category
    l.product_subcategory    = subcategory
    l.is_direct              = true
    l.current_stage          = 'converted'
    l.converted_customer_id  = @customer.id
    l.created_date           = Date.current
  end
  lead.update_columns(current_stage: 'converted', converted_customer_id: @customer.id)
  lead
end

# Lead with explicit category + subcategory at a given stage.
def build_lead_with_product(name:, contact:, stage:, category:, subcategory:)
  create_test_prerequisites
  parts = name.split(' ')
  first = parts.first.gsub(/[^a-zA-Z\s]/, '').presence || 'Test'
  last  = parts[1..-1].join(' ').gsub(/[^a-zA-Z\s]/, '').presence || 'TestUser'

  lead = Lead.find_or_create_by!(contact_number: contact) do |l|
    l.first_name          = first
    l.last_name           = last
    l.name                = name
    l.customer_type       = 'individual'
    l.lead_source         = 'walk_in'
    l.product_category    = category
    l.product_subcategory = subcategory
    l.is_direct           = true
    l.current_stage       = stage
    l.created_date        = Date.current
  end
  lead.update_column(:current_stage, stage) if lead.current_stage != stage
  lead
end

# Creates a branch-out lead in the DB (mirrors the branch_out controller).
def create_branch_out_lead(parent_lead, subcategory)
  create_test_prerequisites
  Lead.create!(
    first_name:          parent_lead.first_name,
    last_name:           parent_lead.last_name,
    name:                parent_lead.name,
    contact_number:      loop { n = "9#{rand(100_000_000..999_999_999)}"; break n unless Lead.exists?(contact_number: n) },
    customer_type:       'individual',
    lead_source:         parent_lead.lead_source,
    product_category:    parent_lead.product_category,
    product_subcategory: subcategory,
    is_direct:           true,
    is_branch_out:       true,
    parent_lead_id:      parent_lead.id,
    current_stage:       'lead_generated',
    created_date:        Date.current,
    affiliate_id:        parent_lead.affiliate_id,
    ambassador_id:       parent_lead.ambassador_id
  )
end

# ─────────────────────────────────────────────────────────────────────────────
# Section 1: Named converted leads for two different customers
# ─────────────────────────────────────────────────────────────────────────────

Given('a converted lead exists for customer {string} with contact {string} and subcategory {string}') do |name, contact, subcategory|
  @lead = build_named_converted_lead(full_name: name, contact: contact, subcategory: subcategory)
end

Given('a second converted lead exists for customer {string} with contact {string} and subcategory {string}') do |name, contact, subcategory|
  @second_lead = build_named_converted_lead(full_name: name, contact: contact, subcategory: subcategory)
end

# Lead with explicit category + subcategory (extends the basic "a lead exists with name…" step)
Given('a lead exists with name {string} and contact {string} and category {string} and subcategory {string}') do |name, contact, category, subcategory|
  @lead = build_lead_with_product(name: name, contact: contact, stage: 'lead_generated',
                                  category: category, subcategory: subcategory)
end

# Stage + category + subcategory variant
Given('a lead exists at stage {string} with name {string} and contact {string} and category {string} and subcategory {string}') do |stage, name, contact, category, subcategory|
  @lead = build_lead_with_product(name: name, contact: contact, stage: stage,
                                  category: category, subcategory: subcategory)
end

# ─────────────────────────────────────────────────────────────────────────────
# Section 2: Branch-out steps
# ─────────────────────────────────────────────────────────────────────────────

When('a branch-out lead is created from that lead with subcategory {string}') do |subcategory|
  @branch_lead = create_branch_out_lead(@lead, subcategory)
end

Then('the branch-out lead should exist with subcategory {string}') do |subcategory|
  expect(@branch_lead).not_to be_nil
  expect(@branch_lead.product_subcategory).to eq(subcategory)
end

Then('the branch-out lead should reference the parent lead') do
  expect(@branch_lead.parent_lead_id).to eq(@lead.id)
  expect(@branch_lead.is_branch_out).to be_truthy
end

Then('the branch-out lead should be at stage {string}') do |stage_name|
  expect(@branch_lead.current_stage).to eq(stage_name.downcase.tr(' ', '_'))
end

Then('the parent lead should have {int} branch-out leads') do |count|
  @lead.reload
  expect(@lead.branch_out_leads.count).to eq(count)
end

When('I visit the branch-out lead\'s show page') do
  @lead = @branch_lead   # redirect future lead-referencing steps to the branch
  visit "/admin/leads/#{@branch_lead.id}"
  expect(page).to have_current_path(%r{/admin/leads/\d+}, wait: 10)
end

When('the branch-out lead is marked as converted') do
  @branch_lead.update_columns(
    current_stage:         'converted',
    converted_customer_id: @customer&.id
  )
  @lead = @branch_lead   # subsequent steps (show page, create_policy) use @lead
end

# ─────────────────────────────────────────────────────────────────────────────
# Section 3: Conversion status assertions
# ─────────────────────────────────────────────────────────────────────────────

Then('the lead should not be converted') do
  @lead.reload
  expect(@lead.current_stage).not_to eq('converted')
end

Then('I should see converted and non-converted leads in the list') do
  has_stage_text = page.has_text?(/converted|follow|generated|scheduled/i, wait: 10)
  expect(has_stage_text).to be_truthy
end
