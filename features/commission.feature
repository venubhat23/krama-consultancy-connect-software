@javascript
Feature: Commission Tracking and Reports
  As an admin
  I want to track commissions, view breakdowns, and generate commission reports
  So that payout management is transparent and auditable

  Background:
    Given I am logged in as admin
    And test prerequisites exist
    And commission test data exists

  # ═══════════════════════════════════════════════════════════════════════════
  # COMMISSION TRACKING — index page
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Admin views the commission tracking index page
    When I visit the commission tracking page
    Then I should be on the commission tracking page
    And I should see commission summary stats

  Scenario: Admin sees all tabs on commission tracking
    When I visit the commission tracking page
    Then I should see the "All" tab
    And I should see the "Paid" tab
    And I should see the "Pending" tab

  Scenario: Admin filters commission tracking by All tab
    When I visit the commission tracking page
    And I click the "All" tab on commission tracking
    Then I should be on the commission tracking page

  Scenario: Admin filters commission tracking by Pending tab
    When I visit the commission tracking page
    And I click the "Pending" tab on commission tracking
    Then I should be on the commission tracking page

  Scenario: Admin marks a policy commission as received
    Given a health insurance policy with commission exists
    When I visit the commission tracking page
    And I mark the first policy commission as received
    Then I should see a commission received confirmation

  Scenario: Admin views commission breakdown for a policy
    Given a health insurance policy with commission exists
    When I visit the commission tracking page
    And I click the commission breakdown for the first policy
    Then I should see the commission breakdown details

  # ═══════════════════════════════════════════════════════════════════════════
  # COMMISSION TRACKING — dashboard
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Admin views commission dashboard
    When I visit the commission tracking dashboard
    Then I should be on the commission tracking dashboard

  # ═══════════════════════════════════════════════════════════════════════════
  # COMMISSION REPORTS — index / saved reports
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Admin views the commission reports page
    When I visit the commission reports page
    Then I should be on the commission reports page
    And I should see the "Generate Commission Report" button

  Scenario: Admin views the generate commission report page
    When I visit the generate commission report page
    Then I should be on the generate commission report page
    And I should see commission report filters

  Scenario: Admin generates a commission report with default filters
    When I visit the generate commission report page
    And I submit the commission report generation form
    Then I should see the commission report was created

  Scenario: Admin generates a commission report filtered by policy type
    When I visit the generate commission report page
    And I select policy type "Health" for the commission report
    And I submit the commission report generation form
    Then I should see the commission report was created

  Scenario: Admin generates a commission report for a custom date range
    When I visit the generate commission report page
    And I set the commission report start date to "2026-01-01"
    And I set the commission report end date to "2026-06-30"
    And I submit the commission report generation form
    Then I should see the commission report was created

  # ═══════════════════════════════════════════════════════════════════════════
  # COMMISSION REPORTS ADVANCED — index
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Admin views the advanced commission reports page
    When I visit the advanced commission reports page
    Then I should be on the advanced commission reports page

  # ═══════════════════════════════════════════════════════════════════════════
  # PROFIT REPORTS
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Admin views the profit reports page
    When I visit the profit reports page
    Then I should be on the profit reports page

  Scenario: Admin views profit reports filtered by date range
    When I visit the profit reports page
    And I apply profit report date range "30_days"
    Then I should be on the profit reports page
