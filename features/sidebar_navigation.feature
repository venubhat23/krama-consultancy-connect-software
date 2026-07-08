@javascript
Feature: Sidebar Navigation
  As an admin
  I want to navigate through all sidebar menu items
  So that I can access all sections of the application

  Background:
    Given I am logged in as admin

  # ============================================================
  # TOP-LEVEL SIDEBAR ITEMS
  # ============================================================
  Scenario: Navigate to Dashboard
    When I click sidebar link "Dashboard"
    Then I should be on the dashboard page
    And the page should load successfully

  Scenario: Navigate to Analytics
    When I click sidebar link "Analytics"
    Then the URL should include "/admin/analytics"
    And the page should load successfully

  Scenario: Navigate to Leads
    When I click sidebar link "Leads"
    Then the URL should include "/admin/leads"
    And the page should load successfully

  Scenario: Navigate to Appointments
    When I click sidebar link "Appointments"
    Then the URL should include "/admin/appointments"
    And the page should load successfully

  Scenario: Navigate to Clients
    When I click sidebar link "Clients"
    Then the URL should include "/admin/customers"
    And the page should load successfully

  Scenario: Navigate to Affiliates
    When I click sidebar link "Affiliates"
    Then the URL should include "/admin"
    And the page should load successfully

  Scenario: Navigate to Distributors/Ambassadors
    When I click sidebar link "Ambassadors"
    Then the URL should include "/admin"
    And the page should load successfully

  # ============================================================
  # INSURANCE SUBMENU
  # ============================================================
  Scenario: Expand Insurance menu
    When I click the Insurance dropdown in the sidebar
    Then I should see the insurance submenu items

  Scenario: Navigate to Life Insurance from sidebar
    When I click the Insurance dropdown in the sidebar
    And I click sidebar submenu link "Life Insurance"
    Then the URL should include "/insurance/life"
    And the page should load successfully

  Scenario: Navigate to Health Insurance from sidebar
    When I click the Insurance dropdown in the sidebar
    And I click sidebar submenu link "Health Insurance"
    Then the URL should include "/insurance/health"
    And the page should load successfully

  Scenario: Navigate to Motor Insurance from sidebar
    When I click the Insurance dropdown in the sidebar
    And I click sidebar submenu link "Motor Insurance"
    Then the URL should include "/insurance/motor"
    And the page should load successfully

  Scenario: Navigate to Other Insurance from sidebar
    When I click the Insurance dropdown in the sidebar
    And I click sidebar submenu link "Other Insurance"
    Then the URL should include "/insurance/other"
    And the page should load successfully

  # ============================================================
  # INVESTMENTS SUBMENU
  # ============================================================
  Scenario: Expand Investments menu and navigate to Mutual Funds
    When I click the Investments dropdown in the sidebar
    And I click sidebar submenu link "Mutual Funds"
    Then the URL should include "/investments/mutual-funds"
    And the page should load successfully

  # ============================================================
  # COMMISSION & FINANCE SECTION
  # ============================================================
  Scenario: Navigate to Brokers
    When I click sidebar link "Brokers"
    Then the URL should include "/admin/brokers"
    And the page should load successfully

  Scenario: Navigate to Agency Codes
    When I click sidebar link "Agency Codes"
    Then the URL should include "/admin/agency_codes"
    And the page should load successfully

  Scenario: Navigate to Commission Tracking
    When I click sidebar link "Commission Tracking"
    Then the URL should include "/admin/commission_tracking"
    And the page should load successfully

  Scenario: Navigate to Affiliate Payouts
    When I click sidebar link "Affiliate Payouts"
    Then the URL should include "/admin/affiliate_payouts"
    And the page should load successfully

  Scenario: Navigate to Distributor Payouts
    When I click sidebar link "Distributor Payouts"
    Then the URL should include "/admin/distributor_payouts"
    And the page should load successfully

  Scenario: Navigate to Invoices
    When I click sidebar link "Invoices"
    Then the URL should include "/admin/invoices"
    And the page should load successfully

  # ============================================================
  # REPORTS SECTION
  # ============================================================
  Scenario: Navigate to Commission Reports
    When I click sidebar link "Commission Reports"
    Then the URL should include "/reports"
    And the page should load successfully

  Scenario: Navigate to Upcoming Renewals report
    When I click sidebar link "Upcoming Renewals"
    Then the URL should include "/reports/upcoming_renewal_reports"
    And the page should load successfully

  # ============================================================
  # SETTINGS SECTION
  # ============================================================
  Scenario: Navigate to User Roles settings
    When I click sidebar link "User Roles"
    Then the URL should include "/settings/user_roles"
    And the page should load successfully

  Scenario: Navigate to Insurance Companies settings
    When I click sidebar link "Insurance Companies"
    Then the URL should include "/admin/insurance_companies"
    And the page should load successfully

  Scenario: Navigate to Investors
    When I click sidebar link "Investors"
    Then the URL should include "/admin/investors"
    And the page should load successfully
