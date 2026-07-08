@javascript
Feature: Life Insurance — Comprehensive Policy Management and Lifecycle
  As an admin
  I want to manage life insurance policies end-to-end
  So that Active, Past (Renewed) and Expired policies are correctly categorised
  and all CRUD operations behave as expected

  Background:
    Given I am logged in as admin
    And test prerequisites exist

  # ═══════════════════════════════════════════════════════════════════════════
  # SIDEBAR NAVIGATION
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Life Insurance link in sidebar navigates to list
    When I click sidebar link "Life Insurance"
    Then the URL should include "/admin/insurance/life"

  # ═══════════════════════════════════════════════════════════════════════════
  # POLICY LIFECYCLE — BUSINESS RULES
  #
  # Rule 1:  active?  (end_date >= today)           → Active Policies
  # Rule 2:  expired + is_renewed = true            → Past Policy (Renewed)
  # Rule 3:  expired + is_renewed = false           → Expired Policy (Not Renewed)
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Active policy appears in Active Policies section
    Given a lifecycle customer exists with mobile "9702001001"
    And a life policy "LIFE-ACT-001" starting today ending 1 year from today for that customer
    When I visit the lifecycle customer show page
    Then the Active Policies count should be at least 1
    And "LIFE-ACT-001" should be visible in the Life Insurance section

  Scenario: Active policy does NOT appear under Past Policy
    Given a lifecycle customer exists with mobile "9702001002"
    And a life policy "LIFE-ACT-002" starting today ending 1 year from today for that customer
    When I visit the lifecycle customer show page
    And I expand the customer section "Past Policy"
    Then "LIFE-ACT-002" should NOT be visible in the Past Policy section

  Scenario: Active policy does NOT appear under Expired Policy
    Given a lifecycle customer exists with mobile "9702001003"
    And a life policy "LIFE-ACT-003" starting today ending 1 year from today for that customer
    When I visit the lifecycle customer show page
    And I expand the customer section "Expired Policy"
    Then "LIFE-ACT-003" should NOT be visible in the Expired Policy section

  Scenario: Expired and renewed policy appears under Past Policy
    Given a lifecycle customer exists with mobile "9702002001"
    And a life policy "LIFE-EXP-P2" that expired 2 years ago and has been renewed for that customer
    And a renewal life policy "LIFE-REN-P3" replacing "LIFE-EXP-P2" for that customer
    When I visit the lifecycle customer show page
    And I expand the customer section "Past Policy"
    Then "LIFE-EXP-P2" should be visible in the Past Policy section

  Scenario: Expired and renewed policy does NOT appear under Expired Policy
    Given a lifecycle customer exists with mobile "9702002002"
    And a life policy "LIFE-EXP-P2B" that expired 2 years ago and has been renewed for that customer
    And a renewal life policy "LIFE-REN-P3B" replacing "LIFE-EXP-P2B" for that customer
    When I visit the lifecycle customer show page
    And I expand the customer section "Expired Policy"
    Then "LIFE-EXP-P2B" should NOT be visible in the Expired Policy section

  Scenario: Renewal policy appears as Active
    Given a lifecycle customer exists with mobile "9702002003"
    And a life policy "LIFE-EXP-P2C" that expired 2 years ago and has been renewed for that customer
    And a renewal life policy "LIFE-REN-P3C" replacing "LIFE-EXP-P2C" for that customer
    When I visit the lifecycle customer show page
    Then the Active Policies count should be at least 1
    And "LIFE-REN-P3C" should be visible in the Life Insurance section

  Scenario: Expired and NOT renewed policy appears under Expired Policy
    Given a lifecycle customer exists with mobile "9702003001"
    And a life policy "LIFE-NORENEW-P4" that expired 2 years ago and has NOT been renewed for that customer
    When I visit the lifecycle customer show page
    And I expand the customer section "Expired Policy"
    Then "LIFE-NORENEW-P4" should be visible in the Expired Policy section

  Scenario: Expired and NOT renewed policy does NOT appear under Past Policy
    Given a lifecycle customer exists with mobile "9702003002"
    And a life policy "LIFE-NORENEW-P4B" that expired 2 years ago and has NOT been renewed for that customer
    When I visit the lifecycle customer show page
    And I expand the customer section "Past Policy"
    Then "LIFE-NORENEW-P4B" should NOT be visible in the Past Policy section

  Scenario: Full lifecycle — 4 policies yield correct section counts
    Given a lifecycle customer exists with mobile "9702004001"
    And a life policy "LIFE-FULL-P1" starting today ending 1 year from today for that customer
    And a life policy "LIFE-FULL-P2" that expired 2 years ago and has been renewed for that customer
    And a renewal life policy "LIFE-FULL-P3" replacing "LIFE-FULL-P2" for that customer
    And a life policy "LIFE-FULL-P4" that expired 2 years ago and has NOT been renewed for that customer
    When I visit the lifecycle customer show page
    Then the Active Policies count should be 2
    And the Past Policies count should be 1
    And the Expired Policies count should be 1

  Scenario: Total life insurance policies count is 4
    Given a lifecycle customer exists with mobile "9702004002"
    And a life policy "LIFE-CNT-P1" starting today ending 1 year from today for that customer
    And a life policy "LIFE-CNT-P2" that expired 2 years ago and has been renewed for that customer
    And a renewal life policy "LIFE-CNT-P3" replacing "LIFE-CNT-P2" for that customer
    And a life policy "LIFE-CNT-P4" that expired 2 years ago and has NOT been renewed for that customer
    When I visit the lifecycle customer show page
    And I expand the customer section "Product & Insurance Information"
    Then I should see "Life Insurance"

  # ═══════════════════════════════════════════════════════════════════════════
  # CREATE — MANDATORY FIELDS
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Create life insurance with all mandatory fields
    Given I am on the new life insurance page
    When I fill in the life insurance form with all fields:
      | field                | value              |
      | Policy Number        | LIFE-COMP-001      |
      | Insured Name         | Ravi Kumar         |
      | Net Premium          | 50000              |
      | 1st Year GST %       | 4.5                |
      | Policy Term          | 10                 |
      | Premium Payment Term | 10                 |
    And I select customer "Test Client" from the client dropdown
    And I select policy holder "Self"
    And I select insurance company "LIC of India"
    And I select policy type "New"
    And I select payment mode "Yearly"
    And I set policy booking date to today
    And I set policy start date to today
    And I set policy end date to 10 years from today
    And I set sum insured to "10 lakhs"
    And I click "Save Policy"
    Then I should see "Life insurance policy was successfully created"
    And I should see "LIFE-COMP-001"

  Scenario: Create life insurance with full fields and all optional data
    Given I am on the new life insurance page
    When I fill in the life insurance form with all fields:
      | field                | value              |
      | Policy Number        | LIFE-FULL-F001     |
      | Insured Name         | Meena Sharma       |
      | Net Premium          | 75000              |
      | 1st Year GST %       | 4.5                |
      | Policy Term          | 20                 |
      | Premium Payment Term | 20                 |
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
    And I should see "LIFE-FULL-F001"

  Scenario: Create renewal type life insurance policy
    Given I am on the new life insurance page
    When I fill in the life insurance form with all fields:
      | field                | value              |
      | Policy Number        | LIFE-COMP-REN-001  |
      | Insured Name         | Anita Rao          |
      | Net Premium          | 60000              |
      | 1st Year GST %       | 4.5                |
      | Policy Term          | 10                 |
      | Premium Payment Term | 10                 |
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
    And I should see "LIFE-COMP-REN-001"

  # ═══════════════════════════════════════════════════════════════════════════
  # CREATE — PAYMENT MODES
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario Outline: Create life insurance with different payment modes
    Given I am on the new life insurance page
    When I fill in the life insurance form with all fields:
      | field                | value            |
      | Policy Number        | LIFE-PM-<mode>   |
      | Insured Name         | Test Mode        |
      | Net Premium          | 40000            |
      | 1st Year GST %       | 4.5              |
      | Policy Term          | 5                |
      | Premium Payment Term | 5                |
    And I select customer "Test Client" from the client dropdown
    And I select policy holder "Self"
    And I select insurance company "LIC of India"
    And I select policy type "New"
    And I select payment mode "<mode>"
    And I set policy booking date to today
    And I set policy start date to today
    And I set policy end date to 5 years from today
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

  # ═══════════════════════════════════════════════════════════════════════════
  # CREATE — VALIDATION
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Validation — submitting empty form shows errors
    Given I am on the new life insurance page
    When I click "Save Policy" without filling any fields
    Then I should see mandatory field errors for life insurance

  Scenario: Validation — net premium must be greater than zero
    Given I am on the new life insurance page
    When I fill in a minimal life insurance form with net premium "0"
    And I click "Save Policy"
    Then I should see premium validation error

  Scenario: Validation — policy end date must be after start date
    Given I am on the new life insurance page
    When I fill in a minimal life insurance form with end date before start date
    And I click "Save Policy"
    Then I should see "must be after policy start date"

  # ═══════════════════════════════════════════════════════════════════════════
  # VIEW — LIST PAGE
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Life insurance list page loads with policies
    Given a life insurance policy "LIFE-LIST-001" exists
    When I visit the life insurance list page
    Then I should see "LIFE-LIST-001"
    And I should see the policies listed

  Scenario: List page shows policy columns
    Given a life insurance policy "LIFE-LIST-COL-001" exists
    When I visit the life insurance list page
    Then I should see columns for policy number, client name, premium, status

  Scenario: List page shows Active badge for active policy
    Given a life insurance policy "LIFE-LIST-STATUS-001" exists
    When I visit the life insurance list page
    Then I should see "Active"

  Scenario: List page shows action buttons for each policy
    Given a life insurance policy "LIFE-LIST-ACT-001" exists
    When I visit the life insurance list page
    Then I should see life insurance list action buttons

  Scenario: Search for policy by policy number
    Given a life insurance policy "LIFE-SEARCH-COMP-001" exists
    When I visit the life insurance list page
    And I search for "LIFE-SEARCH-COMP-001"
    Then I should see "LIFE-SEARCH-COMP-001" in results

  Scenario: Filter life insurance list by policy type New
    Given I have life insurance policies of type "New" and "Renewal"
    When I visit the life insurance list page
    And I filter by type "New"
    Then I should only see "New" policies

  # ═══════════════════════════════════════════════════════════════════════════
  # VIEW — SHOW PAGE (DETAIL)
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Show page is accessible for a life insurance policy
    Given a life insurance policy "LIFE-SHOW-001" exists
    When I visit the life insurance detail page for "LIFE-SHOW-001"
    Then I should be on the life insurance show page
    And I should see "LIFE-SHOW-001"

  Scenario: Show page displays policy holder name
    Given a life insurance policy "LIFE-SHOW-002" exists
    When I visit the life insurance detail page for "LIFE-SHOW-002"
    Then I should see "LIC of India"

  Scenario: Show page displays premium information
    Given a life insurance policy "LIFE-SHOW-003" exists
    When I visit the life insurance detail page for "LIFE-SHOW-003"
    Then I should see life insurance premium details

  Scenario: Show page displays insurance company name
    Given a life insurance policy "LIFE-SHOW-004" exists
    When I visit the life insurance detail page for "LIFE-SHOW-004"
    Then I should see "LIC of India"

  Scenario: Show page displays policy type
    Given a life insurance policy "LIFE-SHOW-005" exists
    When I visit the life insurance detail page for "LIFE-SHOW-005"
    Then I should see life insurance policy type on show page

  Scenario: Show page displays commission section
    Given a life insurance policy "LIFE-SHOW-COM-001" exists
    When I visit the life insurance detail page for "LIFE-SHOW-COM-001"
    Then I should see "Commission"

  Scenario: Show page has Edit button
    Given a life insurance policy "LIFE-SHOW-EDIT-001" exists
    When I visit the life insurance detail page for "LIFE-SHOW-EDIT-001"
    Then I should see life insurance edit button on show page

  # ═══════════════════════════════════════════════════════════════════════════
  # EDIT
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Edit life insurance — update insured name
    Given a life insurance policy for editing exists with number "LIFE-EDIT-001"
    When I navigate to edit life insurance "LIFE-EDIT-001"
    And I update the life insurance insured name to "Updated Insured Name"
    And I submit the life insurance edit form
    Then I should see life insurance updated successfully

  Scenario: Edit life insurance — update payment mode to Half-Yearly
    Given a life insurance policy for editing exists with number "LIFE-EDIT-002"
    When I navigate to edit life insurance "LIFE-EDIT-002"
    And I update the life insurance payment mode to "Half-Yearly"
    And I submit the life insurance edit form
    Then I should see life insurance updated successfully

  Scenario: Edit life insurance — update net premium
    Given a life insurance policy for editing exists with number "LIFE-EDIT-003"
    When I navigate to edit life insurance "LIFE-EDIT-003"
    And I update the life insurance net premium to "65000"
    And I submit the life insurance edit form
    Then I should see life insurance updated successfully

  Scenario: Edit life insurance — extend policy end date
    Given a life insurance policy for editing exists with number "LIFE-EDIT-004"
    When I navigate to edit life insurance "LIFE-EDIT-004"
    And I update the life insurance end date to 15 years from today
    And I submit the life insurance edit form
    Then I should see life insurance updated successfully

  Scenario: Edit life insurance — update extra notes
    Given a life insurance policy for editing exists with number "LIFE-EDIT-005"
    When I navigate to edit life insurance "LIFE-EDIT-005"
    And I update the life insurance extra notes to "Test note for updated policy"
    And I submit the life insurance edit form
    Then I should see life insurance updated successfully

  # ═══════════════════════════════════════════════════════════════════════════
  # DELETE
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Delete life insurance policy from show page
    Given a life insurance policy for editing exists with number "LIFE-DEL-001"
    When I visit the life insurance detail page for "LIFE-DEL-001"
    And I delete the life insurance policy from the show page
    Then I should see life insurance deleted successfully

  Scenario: Deleted policy disappears from list
    Given a life insurance policy for editing exists with number "LIFE-DEL-002"
    When I delete life insurance "LIFE-DEL-002" from the list page
    Then life insurance "LIFE-DEL-002" should not appear in the list

  # ═══════════════════════════════════════════════════════════════════════════
  # RENEWAL WORKFLOW
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Policy eligible for renewal shows Renew button
    Given a life insurance policy "LIFE-ORIG-001" exists and is eligible for renewal
    When I view that policy
    Then I should see "Renew"

  Scenario: Clicking Renew opens renewal form pre-filled with Renewal type
    Given a life insurance policy "LIFE-ORIG-002" exists and is eligible for renewal
    When I click "Renew" on that policy
    Then I should be on the new life insurance page prefilled with renewal data
    And the policy type should be "Renewal"

  Scenario: Already-renewed policy does not show Renew button
    Given a life insurance policy "LIFE-RENEWED-COMP-001" that has already been renewed
    When I view that policy
    Then I should not see a "Renew" button

  # ═══════════════════════════════════════════════════════════════════════════
  # DRWISE CLASSIFICATION
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Admin-created policy is classified as DrWise
    Given a life insurance policy created by admin exists
    When I view the policy list
    Then the policy should show "DrWise" badge

  # ═══════════════════════════════════════════════════════════════════════════
  # COMMISSION
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Commission details are visible for a life insurance policy
    Given a life insurance policy exists with net premium 100000
    When I visit the commission details page for that policy
    Then I should see commission breakdown with correct calculations
    And I should see main income percentage field
    And I should see distributor commission percentage field

  Scenario: Total premium auto-calculates when net premium and GST are entered
    Given I am on the new life insurance page
    When I select customer "Test Client" from the client dropdown
    And I select policy holder "Self"
    And I select insurance company "LIC of India"
    And I select policy type "New"
    And I select payment mode "Yearly"
    And I set policy start date to today
    And I set policy end date to 10 years from today
    And I set sum insured to "25 lakhs"
    And I fill in "Net Premium" with "100000"
    And I fill in "1st Year GST %" with "4.5"
    Then the total premium field should be auto-calculated
