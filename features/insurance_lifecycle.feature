@javascript
Feature: Insurance Policy Lifecycle — End-to-End
  As an admin I want to manage the full lifecycle of all insurance types:
  create, edit, delete, deactivate, view past policies, trace commissions, and renew.

  Background:
    Given I am logged in as admin
    And test prerequisites exist

  # ================================================================
  # HEALTH INSURANCE LIFECYCLE
  # ================================================================

  Scenario: Edit a health insurance policy and verify update
    Given a health insurance policy "HEALTH-EDIT-001" exists for test customer
    When I visit that health insurance policy's edit page
    And I update the health insurance additional details to "BDD test update - health"
    And I submit the health insurance edit form
    Then I should see "Health insurance policy was successfully updated"

  Scenario: Delete a health insurance policy and verify deletion
    Given a health insurance policy "HEALTH-DEL-001" exists for test customer
    When I delete the health insurance policy via the list page
    Then the health insurance policy "HEALTH-DEL-001" should no longer exist

  Scenario: Deactivate a health insurance policy by setting status to Cancelled
    Given a health insurance policy "HEALTH-DEACT-001" exists for test customer
    When I visit that health insurance policy's edit page
    And I set the health insurance status to "Cancelled"
    And I submit the health insurance edit form
    Then the health insurance show page should display status "cancelled"

  Scenario: Past health insurance policy appears under expired filter
    Given a health insurance policy "HEALTH-PAST-001" exists with start date 3 years ago and end date 1 year ago
    When I visit the health insurance list with expired status filter
    Then I should see "HEALTH-PAST-001" in the health insurance list

  Scenario: Health insurance policy appears in customer commission trace
    Given a health insurance policy "HEALTH-TRACE-001" exists for test customer
    When I visit the commission trace page for the test customer
    Then I should see "Health Insurance" in the product portfolio

  Scenario: Renew a health insurance policy and verify renewal creation
    Given a health insurance policy "HEALTH-ORIG-RENEW-01" exists and is due for renewal
    When I visit the health insurance renewal page for that policy
    And I set the renewal health policy number to "HEALTH-ORIG-RENEW-01-R1"
    And I set the renewal health policy start date to today
    And I set the renewal health policy end date to 1 year from today
    And I submit the health renewal form
    Then I should see "Health insurance renewal policy was successfully created"

  # ================================================================
  # LIFE INSURANCE LIFECYCLE
  # ================================================================

  Scenario: Edit a life insurance policy and verify update
    Given a life insurance policy "LIFE-EDIT-001" exists for test customer
    When I visit that life insurance policy's edit page
    And I update the life insurance extra note to "BDD test update - life"
    And I submit the life insurance edit form
    Then I should see "Life insurance policy was successfully updated"

  Scenario: Delete a life insurance policy and verify deletion
    Given a life insurance policy "LIFE-DEL-001" exists for test customer
    When I delete the life insurance policy via the list page
    Then the life insurance policy "LIFE-DEL-001" should no longer exist

  Scenario: Deactivate a life insurance policy by marking it inactive
    Given a life insurance policy "LIFE-DEACT-001" exists for test customer
    When I deactivate the life insurance policy "LIFE-DEACT-001" directly
    Then the life insurance policy "LIFE-DEACT-001" should be inactive

  Scenario: Past life insurance policy appears under expired filter
    Given a life insurance policy "LIFE-PAST-001" exists with start date 3 years ago and end date 1 year ago
    When I visit the life insurance list with expired status filter
    Then I should see "LIFE-PAST-001" in the life insurance list

  Scenario: Life insurance policy appears in customer commission trace
    Given a life insurance policy "LIFE-TRACE-001" exists for test customer
    When I visit the commission trace page for the test customer
    Then I should see "Life Insurance" in the product portfolio

  Scenario: Renew a life insurance policy and verify renewal creation
    Given a life insurance policy "LIFE-ORIG-RENEW-01" exists and is due for renewal
    When I visit the life insurance renewal page for that policy
    And I set the renewal life policy number to "LIFE-ORIG-RENEW-01-R1"
    And I set the renewal life policy start date to today
    And I set the renewal life policy end date to 10 years from today
    And I submit the life renewal form
    Then I should see "Life insurance policy was successfully created"

  # ================================================================
  # MOTOR INSURANCE LIFECYCLE
  # ================================================================

  Scenario: Edit a motor insurance policy and verify update
    Given a motor insurance policy "MOTOR-EDIT-001" exists for test customer
    When I visit that motor insurance policy's edit page
    And I update the motor insurance extra note to "BDD test update - motor"
    And I submit the motor insurance edit form
    Then I should see "Motor insurance policy was successfully updated"

  Scenario: Delete a motor insurance policy and verify deletion
    Given a motor insurance policy "MOTOR-DEL-001" exists for test customer
    When I delete the motor insurance policy via the list page
    Then the motor insurance policy "MOTOR-DEL-001" should no longer exist

  Scenario: Deactivate a motor insurance policy by marking it cancelled
    Given a motor insurance policy "MOTOR-DEACT-001" exists for test customer
    When I deactivate the motor insurance policy "MOTOR-DEACT-001" directly
    Then the motor insurance policy "MOTOR-DEACT-001" should be cancelled

  Scenario: Past motor insurance policy appears under expired filter
    Given a motor insurance policy "MOTOR-PAST-001" exists with start date 3 years ago and end date 1 year ago
    When I visit the motor insurance list with expired status filter
    Then I should see "MOTOR-PAST-001" in the motor insurance list

  Scenario: Motor insurance policy appears in customer commission trace
    Given a motor insurance policy "MOTOR-TRACE-001" exists for test customer
    When I visit the commission trace page for the test customer
    Then I should see "Motor Insurance" in the product portfolio

  Scenario: Renew a motor insurance policy and verify renewal creation
    Given a motor insurance policy "MOTOR-ORIG-RENEW-01" exists and is due for renewal
    When I visit the motor insurance renewal page for that policy
    And I set the renewal motor policy number to "MOTOR-ORIG-RENEW-01-R1"
    And I set the renewal motor policy start date to today
    And I set the renewal motor policy end date to 1 year from today
    And I submit the motor renewal form
    Then I should see "Motor insurance renewal policy was successfully created"

  # ================================================================
  # OTHER / GENERAL INSURANCE LIFECYCLE
  # ================================================================

  Scenario: Edit an other insurance policy and verify update
    Given an other insurance policy "OTHER-EDIT-001" exists for test customer
    When I visit that other insurance policy's edit page
    And I update the other insurance extra note to "BDD test update - other"
    And I submit the other insurance edit form
    Then I should see "Other insurance policy was successfully updated"

  Scenario: Delete an other insurance policy and verify deletion
    Given an other insurance policy "OTHER-DEL-001" exists for test customer
    When I delete the other insurance policy via the list page
    Then the other insurance policy "OTHER-DEL-001" should no longer exist

  Scenario: Deactivate an other insurance policy by setting status to Cancelled
    Given an other insurance policy "OTHER-DEACT-001" exists for test customer
    When I visit that other insurance policy's edit page
    And I set the other insurance status to "Cancelled"
    And I submit the other insurance edit form
    Then the other insurance show page should display status "cancelled"

  Scenario: Past other insurance policy appears under expired filter
    Given an other insurance policy "OTHER-PAST-001" exists with start date 3 years ago and end date 1 year ago
    When I visit the other insurance list with expired status filter
    Then I should see "OTHER-PAST-001" in the other insurance list

  Scenario: Other insurance policy appears in customer commission trace
    Given an other insurance policy "OTHER-TRACE-001" exists for test customer
    When I visit the commission trace page for the test customer
    Then I should see any insurance type in the product portfolio

  Scenario: Renew an other insurance policy and verify renewal creation
    Given an other insurance policy "OTHER-ORIG-RENEW-01" exists and is due for renewal
    When I visit the other insurance renewal page for that policy
    And I set the renewal other policy number to "OTHER-ORIG-RENEW-01-R1"
    And I set the renewal other policy start date to today
    And I set the renewal other policy end date to 1 year from today
    And I submit the other renewal form
    Then I should see "Other insurance renewal policy was successfully created"

  # ================================================================
  # PAST POLICY: Not renewable because end date is in the past
  # ================================================================

  Scenario: Past health insurance policy is not eligible for renewal
    Given a health insurance policy "HEALTH-NOT-RENEW-01" exists with start date 3 years ago and end date 1 year ago
    When I visit the health insurance list with expired status filter
    Then "HEALTH-NOT-RENEW-01" should be listed as expired but not renewable
