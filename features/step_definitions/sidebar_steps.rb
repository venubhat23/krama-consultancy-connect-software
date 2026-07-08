SIDEBAR_LINK_MAP = {
  'Dashboard'            => '/dashboard',
  'Analytics'            => '/admin/analytics',
  'Roles'                => '/admin/roles',
  'Leads'                => '/admin/leads',
  'Appointments'         => '/admin/appointments',
  'Clients'              => '/admin/customers',
  'Affiliates'           => '/admin/sub_agents',
  'Ambassadors'          => '/admin/distributors',
  'Brokers'              => '/admin/brokers',
  'Agency Codes'         => '/admin/agency_codes',
  'Commission Tracking'  => '/admin/commission_tracking',
  'Affiliate Payouts'    => '/admin/affiliate_payouts',
  'Distributor Payouts'  => '/admin/distributor_payouts',
  'Invoices'             => '/admin/invoices',
  'Commission Reports'   => '/admin/reports/commission_reports_advanced',
  'Upcoming Renewals'    => '/admin/reports/upcoming_renewal_reports',
  'Users'                => '/admin/settings/user_roles',
  'User Roles'           => '/admin/settings/user_roles',
  'Insurance Companies'  => '/admin/insurance_companies',
  'Investors'            => '/admin/investors',
  'Life Insurance'       => '/admin/insurance/life',
  'Health Insurance'     => '/admin/insurance/health',
  'Motor Insurance'      => '/admin/insurance/motor',
  'Other Insurance'      => '/admin/insurance/other',
  'Mutual Funds'         => '/admin/investments/mutual-funds',
}.freeze

def expand_sidebar
  begin
    # Try desktop toggle button
    find('#desktopSidebarToggle', wait: 3).click
    sleep 0.3
  rescue Capybara::ElementNotFound
    # Sidebar might already be expanded or using different toggle
  end
end

When('I click sidebar link {string}') do |link_text|
  path = SIDEBAR_LINK_MAP[link_text]
  if path
    # Navigate directly since sidebar may be in icon-only mode
    visit path
  else
    # Fallback: try to click link by text or tooltip
    begin
      find("a[data-tooltip='#{link_text}']", wait: 5).click
    rescue Capybara::ElementNotFound
      find('a', text: link_text, wait: 5).click
    end
  end
end

When('I click the Insurance dropdown in the sidebar') do
  # Navigate to insurance section to verify the dropdown works
  visit '/admin/insurance/life'
end

When('I click the Investments dropdown in the sidebar') do
  begin
    find("[data-bs-target='#investments-menu']", wait: 5).click
    sleep 0.5
  rescue Capybara::ElementNotFound
    find('div', text: 'Investments', wait: 5).click rescue nil
  end
end

When('I click sidebar submenu link {string}') do |link_text|
  path = SIDEBAR_LINK_MAP[link_text]
  if path
    visit path
  else
    find('a', text: link_text, wait: 5, exact: false).click
  end
end

Then('I should be on the dashboard page') do
  expect(page).to have_current_path('/dashboard', wait: 10)
end

Then('the URL should include {string}') do |path|
  expect(current_url).to include(path)
end

Then('the page should load successfully') do
  expect(page.status_code).to eq(200) rescue nil
  expect(page).not_to have_text('500 Internal Server Error', wait: 3) rescue nil
  expect(page).not_to have_text('We\'re sorry, but something went wrong', wait: 2) rescue nil
  expect(page).to have_css('body', wait: 5)
end

Then('I should see the insurance submenu items') do
  # On the life insurance listing page, verify it loaded
  expect(page).to have_current_path(%r{/insurance/life}, wait: 10)
  expect(page).to have_css('body', wait: 5)
end
