@javascript
Feature: Health Insurance Management
  As an admin
  I want to manage health insurance policies
  So that I can create, view, and renew health insurance records

  Background:
    Given I am logged in as admin
    And test prerequisites exist

  Scenario: Create health insurance with all mandatory fields
    Given I am on the new health insurance page
    When I fill in the health insurance form with all fields:
      | field            | value            |
      | Policy Number    | HEALTH-TEST-001  |
      | Net Premium      | 25000            |
      | GST %            | 18               |
    And I select customer "Test Client" from the health client dropdown
    And I select health insurance type "Individual"
    And I select health policy type "New"
    And I select health insurance company "LIC of India"
    And I select health payment mode "Yearly"
    And I set health policy start date to today
    And I set health policy end date to 1 year from today
    And I set health sum insured to "5 lakhs"
    And I click "Create Policy"
    Then I should see "Health insurance policy was successfully created"
    And I should see "HEALTH-TEST-001"

  Scenario: Health insurance mandatory field validation
    Given I am on the new health insurance page
    When I click "Create Policy" without filling any fields
    Then I should see health insurance validation errors

  Scenario: Create Family Floater health insurance
    Given I am on the new health insurance page
    When I fill in the health insurance form with all fields:
      | field            | value            |
      | Policy Number    | HEALTH-FAM-001   |
      | Net Premium      | 35000            |
    And I select customer "Test Client" from the health client dropdown
    And I select health insurance type "Family Floater"
    And I select health policy type "New"
    And I select health insurance company "LIC of India"
    And I select health payment mode "Yearly"
    And I set health policy start date to today
    And I set health policy end date to 1 year from today
    And I set health sum insured to "10 lakhs"
    And I click "Create Policy"
    Then I should see "Health insurance policy was successfully created"

  Scenario: Health insurance renewal
    Given a health insurance policy "HEALTH-ORIG-001" exists and is eligible for renewal
    When I click "Renew" on that health policy
    Then I should be on the new health insurance page prefilled with renewal data

  Scenario: Renew health insurance via Porting type
    Given I am on the new health insurance page
    When I fill in the health insurance form with all fields:
      | field            | value            |
      | Policy Number    | HEALTH-PORT-001  |
      | Net Premium      | 28000            |
    And I select customer "Test Client" from the health client dropdown
    And I select health insurance type "Individual"
    And I select health policy type "Porting"
    And I select health insurance company "LIC of India"
    And I select health payment mode "Yearly"
    And I set health policy start date to today
    And I set health policy end date to 1 year from today
    And I set health sum insured to "5 lakhs"
    And I click "Create Policy"
    Then I should see "Health insurance policy was successfully created"

  Scenario Outline: Create health insurance with different types
    Given I am on the new health insurance page
    When I fill in the health insurance form with all fields:
      | field            | value                |
      | Policy Number    | HEALTH-<type>-001    |
      | Net Premium      | 20000                |
    And I select customer "Test Client" from the health client dropdown
    And I select health insurance type "Individual"
    And I select health policy type "<type>"
    And I select health insurance company "LIC of India"
    And I select health payment mode "Yearly"
    And I set health policy start date to today
    And I set health policy end date to 1 year from today
    And I set health sum insured to "5 lakhs"
    And I click "Create Policy"
    Then I should see "Health insurance policy was successfully created"

    Examples:
      | type       |
      | New        |
      | Renewal    |
      | Porting    |

  Scenario: List health insurance policies
    Given I have multiple health insurance policies
    When I visit the health insurance list page
    Then I should see health insurance policies listed
