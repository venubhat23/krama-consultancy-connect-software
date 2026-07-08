@javascript
Feature: Admin Dashboard
  As an admin
  I want to see a comprehensive dashboard with KPI cards, charts, and alerts
  So that I can get a real-time overview of the business

  Background:
    Given I am logged in as admin
    And test prerequisites exist
    And I seed dashboard test data

  Scenario: Dashboard page loads without errors
    When I visit the dashboard page
    Then the page should load successfully
    And I should not see any server errors
    And the current URL should include "dashboard"

  Scenario: KPI cards are visible with correct labels
    When I visit the dashboard page
    Then I should see "Total Customers"
    And I should see "Total Policies"
    And I should see "Total Premium"
    And I should see "Active Leads"

  Scenario: KPI card values are numeric and not blank
    When I visit the dashboard page
    Then the "Total Customers" KPI value should be numeric
    And the "Total Policies" KPI value should be numeric
    And the "Total Premium" KPI value should be present

  Scenario: Revenue chart canvas is rendered
    When I visit the dashboard page
    Then the chart canvas "revenueChart" should be present in the DOM
    And the chart canvas "policyChart" should be present in the DOM

  Scenario: Charts are initialized by Chart.js
    When I visit the dashboard page
    Then the chart "revenueChart" should be initialized by Chart.js
    And the chart "policyChart" should be initialized by Chart.js

  Scenario: Renewal alerts section is visible
    When I visit the dashboard page
    Then I should see "Renewal Alerts"
    And I should see "Expiring in 30 days"

  Scenario: Policy breakdown by insurance type is shown
    When I visit the dashboard page
    Then the dashboard should show policy counts for health insurance
    And the dashboard should show policy counts for life insurance
    And the dashboard should show policy counts for motor insurance

  Scenario: Year filter applies and page reloads
    When I visit the dashboard page
    And I filter the dashboard by year "2025"
    Then the page should load successfully
    And I should see "Total Customers"
    And I should see "Total Policies"
    And the filter should reflect year "2025"

  Scenario: Month filter applies
    When I visit the dashboard page
    And I filter the dashboard by month "January"
    Then the page should load successfully
    And the month filter should show "January"

  Scenario: Date range filter applies
    When I visit the dashboard with date range "2025-01-01" to "2025-12-31"
    Then the page should load successfully
    And I should see "Total Customers"

  Scenario: Dashboard shows no NaN or undefined in KPI values
    When I visit the dashboard page
    Then the KPI cards should not display NaN or undefined
    And the KPI cards should not display blank values

  Scenario: Dashboard KPI card click opens detail modal
    When I visit the dashboard page
    And I click the "Total Customers" KPI card
    Then a detail modal should appear

  Scenario: Dashboard with insurance data shows non-zero policy count
    When I visit the dashboard page
    Then the total policies count should reflect seeded data
