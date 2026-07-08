@javascript
Feature: Analytics Page
  As an admin
  I want to view detailed analytics with KPI cards and multiple chart sections
  So that I can understand business performance across all dimensions

  Background:
    Given I am logged in as admin
    And test prerequisites exist
    And I seed dashboard test data

  Scenario: Analytics page loads without errors
    When I visit the analytics page
    Then the page should load successfully
    And I should not see any server errors
    And the current URL should include "analytics"

  Scenario: All 5 KPI cards are visible
    When I visit the analytics page
    Then I should see "TOTAL CUSTOMERS"
    And I should see "TOTAL POLICIES"
    And I should see "TOTAL PREMIUM"
    And I should see "TOTAL INVESTORS"
    And I should see "TOTAL AFFILIATES"

  Scenario: KPI card values are numeric and present
    When I visit the analytics page
    Then the analytics "Total Customers" KPI should be numeric
    And the analytics "Total Policies" KPI should be numeric
    And the analytics "Total Investors" KPI should be numeric
    And the analytics "Total Affiliates" KPI should be numeric

  Scenario: Lead Analytics section has both charts
    When I visit the analytics page
    Then I should see "Lead Analytics"
    And I should see "Lead Conversion Funnel"
    And I should see "Lead Stage Distribution"
    And the chart canvas "leadFunnelChart" should be present in the DOM
    And the chart canvas "leadStageChart" should be present in the DOM

  Scenario: Customer Analytics section has charts
    When I visit the analytics page
    Then I should see "Customer Analytics"
    And I should see "Customer Acquisition Trend"
    And I should see "Monthly Trends"
    And the chart canvas "customerAcquisitionChart" should be present in the DOM
    And the chart canvas "monthlyTrendsChart" should be present in the DOM

  Scenario: Policy Analytics section has premium and distribution charts
    When I visit the analytics page
    Then I should see "Policy Analytics"
    And I should see "Premium Revenue Trend"
    And I should see "Policy Distribution"
    And I should see "Renewal Analytics"
    And the chart canvas "premiumRevenueTrendChart" should be present in the DOM
    And the chart canvas "policyDistributionChart" should be present in the DOM
    And the chart canvas "renewalChart" should be present in the DOM

  Scenario: Commission analytics section has chart
    When I visit the analytics page
    Then I should see "Commission & Affiliate Analytics"
    And I should see "Commission Summary"
    And the chart canvas "commissionChart" should be present in the DOM

  Scenario: Investor analytics section is visible
    When I visit the analytics page
    Then I should see "Investor Analytics"
    And the chart canvas "investorAmbassadorChart" should be present in the DOM

  Scenario: All analytics charts are initialized by Chart.js
    When I visit the analytics page
    Then the chart "leadFunnelChart" should be initialized by Chart.js
    And the chart "leadStageChart" should be initialized by Chart.js
    And the chart "customerAcquisitionChart" should be initialized by Chart.js
    And the chart "premiumRevenueTrendChart" should be initialized by Chart.js
    And the chart "policyDistributionChart" should be initialized by Chart.js
    And the chart "commissionChart" should be initialized by Chart.js

  Scenario: Analytics KPI values do not show NaN or undefined
    When I visit the analytics page
    Then the analytics KPI cards should not display NaN or undefined

  Scenario: Analytics year filter updates the date range shown
    When I visit the analytics page with year "2025"
    Then the page should load successfully
    And I should see "2025"
    And I should see "TOTAL CUSTOMERS"

  Scenario: Analytics date range filter applies custom range
    When I visit the analytics page with start date "2025-01-01" and end date "2025-06-30"
    Then the page should load successfully
    And I should see "Jan 2025"

  Scenario: Analytics month filter narrows to single month
    When I visit the analytics page with year "2025" and month "3"
    Then the page should load successfully
    And I should see "TOTAL POLICIES"

  Scenario: Analytics KPI card click opens detail modal
    When I visit the analytics page
    And I click the analytics "Total Customers" KPI card
    Then a detail modal should appear

  Scenario: Lead activity table section is visible
    When I visit the analytics page
    Then I should see "Recent Lead Activities"

  Scenario: Policy performance metrics chart is rendered
    When I visit the analytics page
    Then I should see "Policy Performance Metrics"
    And the chart canvas "policyPerformanceChart" should be present in the DOM

  Scenario: Operations overview chart is rendered
    When I visit the analytics page
    Then I should see "Operations Overview"
    And the chart canvas "operationsChart" should be present in the DOM

  Scenario: Analytics shows correct lead conversion rate format
    When I visit the analytics page
    Then the "LEAD CONVERSION RATE" metric should show a percentage value

  Scenario: Analytics avg policy value is displayed
    When I visit the analytics page
    Then the "AVG POLICY VALUE" metric should be present
