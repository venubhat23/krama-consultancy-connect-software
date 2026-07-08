@javascript
Feature: Admin Reports — Expired Insurance, Upcoming Renewals, Payment Due, All Policies, Leads
  As an admin
  I want to view and export operational reports
  So that I can manage policy renewals, payments, and lead performance

  Background:
    Given I am logged in as admin
    And test prerequisites exist
    And report test data exists

  # ═══════════════════════════════════════════════════════════════════════════
  # EXPIRED INSURANCE REPORTS
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Admin views expired insurance reports page
    When I visit the expired insurance reports page
    Then I should be on the expired insurance reports page
    And I should see expired policy summary stats

  Scenario: Admin sees expired policies listed
    Given an expired health insurance policy exists
    When I visit the expired insurance reports page
    Then I should see at least one expired policy record

  Scenario: Admin generates an expired insurance report
    When I visit the expired insurance reports page
    And I click generate report for expired insurance
    Then I should see the expired insurance report form

  # ═══════════════════════════════════════════════════════════════════════════
  # UPCOMING RENEWAL REPORTS
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Admin views upcoming renewal reports page
    When I visit the upcoming renewal reports page
    Then I should be on the upcoming renewal reports page
    And I should see upcoming renewal summary stats

  Scenario: Admin sees policies due for renewal
    Given a health insurance policy expiring within 30 days exists
    When I visit the upcoming renewal reports page
    Then I should see at least one upcoming renewal record

  Scenario: Admin generates an upcoming renewal report
    When I visit the upcoming renewal reports page
    And I click generate report for upcoming renewals
    Then I should see the upcoming renewal report form

  # ═══════════════════════════════════════════════════════════════════════════
  # PAYMENT DUE REPORTS
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Admin views payment due reports page
    When I visit the payment due reports page
    Then I should be on the payment due reports page

  # ═══════════════════════════════════════════════════════════════════════════
  # ALL POLICY REPORTS
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Admin views all policy reports page
    When I visit the all policy reports page
    Then I should be on the all policy reports page

  Scenario: Admin navigates to new all policy report form
    When I visit the new all policy report page
    Then I should be on the new all policy report page
    And I should see policy report filter options

  Scenario Outline: Admin generates a policy report for a specific type
    When I visit the new all policy report page
    And I select policy type "<policy_type>" for the all-policy report
    And I submit the all-policy report form
    Then I should see a saved all-policy report

    Examples:
      | policy_type |
      | Health      |
      | Life        |
      | Motor       |

  Scenario: Admin views all policy reports page and sees policy data
    When I visit the all policy reports page
    Then I should be on the all policy reports page
    And I should see "All Policy Reports"

  Scenario: Admin uses generate commission report for all-policy tracking
    Given a saved all-policy report exists
    When I visit the commission reports page
    Then I should be on the commission reports page

  # ═══════════════════════════════════════════════════════════════════════════
  # LEADS REPORTS
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Admin views leads reports page
    When I visit the leads reports page
    Then I should be on the leads reports page
    And I should see lead report summary stats

  Scenario: Admin filters leads report by date range
    When I visit the leads reports page
    And I apply lead report date range "30_days"
    Then I should be on the leads reports page

  Scenario: Admin filters leads report by status
    When I visit the leads reports page
    And I filter leads report by status "new"
    Then I should be on the leads reports page

  # ═══════════════════════════════════════════════════════════════════════════
  # UPCOMING PAYMENT REPORTS
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Admin views upcoming payment reports page
    When I visit the upcoming payment reports page
    Then I should be on the upcoming payment reports page
