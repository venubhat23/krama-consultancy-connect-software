@javascript
Feature: Life Insurance Management
  As an admin
  I want to manage life insurance policies
  So that I can create, view, renew and track commissions

  Background:
    Given I am logged in as admin
    And test prerequisites exist

  # ============================================================
  # SCENARIO 1: Create Life Insurance with all fields
  # ============================================================
  Scenario: Create life insurance with all mandatory and optional fields
    Given I am on the new life insurance page
    When I fill in the life insurance form with all fields:
      | field                     | value             |
      | Policy Number             | LIFE-TEST-001     |
      | Insured Name              | John Doe          |
      | Net Premium               | 50000             |
      | 1st Year GST %            | 4.5               |
      | Policy Term               | 20                |
      | Premium Payment Term      | 20                |
    And I select customer "Test Client" from the client dropdown
    And I select policy holder "Self"
    And I select insurance company "LIC of India"
    And I select policy type "New"
    And I select payment mode "Yearly"
    And I set policy booking date to today
    And I set policy start date to today
    And I set policy end date to 20 years from today
    And I set sum insured to "50 lakhs"
    And I click "Save Policy"
    Then I should see "Life insurance policy was successfully created"
    And I should see "LIFE-TEST-001"

  # ============================================================
  # SCENARIO 2: Mandatory field validation
  # ============================================================
  Scenario: Show validation errors when mandatory fields are missing
    Given I am on the new life insurance page
    When I click "Save Policy" without filling any fields
    Then I should see mandatory field errors for life insurance

  Scenario: Validate policy number is required
    Given I am on the new life insurance page
    When I fill in a minimal life insurance form without policy number
    And I click "Save Policy"
    Then I should see "Policy number" error or be blocked by browser validation

  Scenario: Validate net premium must be greater than 0
    Given I am on the new life insurance page
    When I fill in a minimal life insurance form with net premium "0"
    And I click "Save Policy"
    Then I should see premium validation error

  Scenario: Validate policy end date must be after start date
    Given I am on the new life insurance page
    When I fill in a minimal life insurance form with end date before start date
    And I click "Save Policy"
    Then I should see "must be after policy start date"

  # ============================================================
  # SCENARIO 3: Commission calculation
  # ============================================================
  Scenario: Verify commission calculation is correct
    Given a life insurance policy exists with net premium 100000
    When I visit the commission details page for that policy
    Then I should see commission breakdown with correct calculations
    And I should see main income percentage field
    And I should see sub-agent commission percentage field
    And I should see distributor commission percentage field
    And I should see total premium field

  Scenario: Commission auto-calculates when net premium is entered
    Given I am on the new life insurance page
    When I select customer "Test Client" from the client dropdown
    And I select policy holder "Self"
    And I select insurance company "LIC of India"
    And I select policy type "New"
    And I select payment mode "Yearly"
    And I set policy start date to today
    And I set policy end date to 10 years from today
    And I set sum insured to "50 lakhs"
    And I fill in "Net Premium" with "100000"
    And I fill in "1st Year GST %" with "4.5"
    Then the total premium field should be auto-calculated

  # ============================================================
  # SCENARIO 4: Renewal scenarios
  # ============================================================
  Scenario: Create renewal life insurance policy
    Given I am on the new life insurance page
    When I fill in the life insurance form with all fields:
      | field                | value         |
      | Policy Number        | LIFE-RENEW-001|
      | Insured Name         | Jane Doe      |
      | Net Premium          | 60000         |
      | 1st Year GST %       | 4.5           |
      | Policy Term          | 10            |
    And I select customer "Test Client" from the client dropdown
    And I select policy holder "Self"
    And I select insurance company "LIC of India"
    And I select policy type "Renewal"
    And I select payment mode "Yearly"
    And I set policy booking date to today
    And I set policy start date to today
    And I set policy end date to 10 years from today
    And I set sum insured to "25 lakhs"
    And I click "Save Policy"
    Then I should see "Life insurance policy was successfully created"
    And I should see "LIFE-RENEW-001"

  Scenario: Renew an existing life insurance policy
    Given a life insurance policy "LIFE-ORIG-001" exists and is eligible for renewal
    When I click "Renew" on that policy
    Then I should be on the new life insurance page prefilled with renewal data
    And the policy type should be "Renewal"

  Scenario: Cannot renew a policy that is already renewed
    Given a life insurance policy "LIFE-RENEWED-001" that has already been renewed
    When I view that policy
    Then I should not see a "Renew" button

  # ============================================================
  # SCENARIO 5: DrWise vs Non-DrWise (First vs Not First)
  # ============================================================
  Scenario: Admin-created policy is classified as DrWise
    Given a life insurance policy created by admin exists
    When I view the policy list
    Then the policy should show "DrWise" badge

  Scenario: List page shows all life insurance policies
    Given I have multiple life insurance policies
    When I visit the life insurance list page
    Then I should see the policies listed
    And I should see columns for policy number, client name, premium, status

  # ============================================================
  # SCENARIO 6: Search and filter
  # ============================================================
  Scenario: Search life insurance by policy number
    Given a life insurance policy "LIFE-SEARCH-001" exists
    When I visit the life insurance list page
    And I search for "LIFE-SEARCH-001"
    Then I should see "LIFE-SEARCH-001" in results

  Scenario: Filter life insurance by policy type New
    Given I have life insurance policies of type "New" and "Renewal"
    When I visit the life insurance list page
    And I filter by type "New"
    Then I should only see "New" policies

  # ============================================================
  # SCENARIO 7: Payment modes
  # ============================================================
  Scenario Outline: Create life insurance with different payment modes
    Given I am on the new life insurance page
    When I fill in the life insurance form with all fields:
      | field         | value         |
      | Policy Number | LIFE-PM-<mode>|
      | Net Premium   | 50000         |
      | Policy Term   | 10            |
    And I select customer "Test Client" from the client dropdown
    And I select policy holder "Self"
    And I select insurance company "LIC of India"
    And I select policy type "New"
    And I select payment mode "<mode>"
    And I set policy start date to today
    And I set policy end date to 10 years from today
    And I set sum insured to "10 lakhs"
    And I click "Save Policy"
    Then I should see "Life insurance policy was successfully created"

    Examples:
      | mode        |
      | Yearly      |
      | Half-Yearly |
      | Quarterly   |
      | Monthly     |
      | Single      |
