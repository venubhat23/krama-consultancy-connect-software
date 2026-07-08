@javascript
Feature: Other Insurance — Comprehensive Policy Management and Lifecycle
  As an admin
  I want to manage general/other insurance policies end-to-end
  So that Active, Past (Renewed) and Expired policies are correctly categorised
  and all CRUD operations behave as expected

  Background:
    Given I am logged in as admin
    And test prerequisites exist

  # ═══════════════════════════════════════════════════════════════════════════
  # SIDEBAR NAVIGATION
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Other Insurance link in sidebar navigates to list
    When I click sidebar link "Other Insurance"
    Then the URL should include "/admin/insurance/other"

  # ═══════════════════════════════════════════════════════════════════════════
  # POLICY LIFECYCLE — BUSINESS RULES
  #
  # Rule 1:  active?  (end_date >= today)           → Active Policies
  # Rule 2:  expired + is_renewed = true            → Past Policy (Renewed)
  # Rule 3:  expired + is_renewed = false           → Expired Policy (Not Renewed)
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Active other insurance policy appears in Active Policies section
    Given an other lifecycle customer exists with mobile "9705001001"
    And an other policy "OTH-ACT-001" starting today ending 1 year from today for that customer
    When I visit the other lifecycle customer show page
    Then the Active Policies count should be at least 1
    And "OTH-ACT-001" should be visible in the Other Insurance section

  Scenario: Active other policy does NOT appear under Past Policy
    Given an other lifecycle customer exists with mobile "9705001002"
    And an other policy "OTH-ACT-002" starting today ending 1 year from today for that customer
    When I visit the other lifecycle customer show page
    And I expand the customer section "Past Policy"
    Then "OTH-ACT-002" should NOT be visible in the other Past Policy section

  Scenario: Active other policy does NOT appear under Expired Policy
    Given an other lifecycle customer exists with mobile "9705001003"
    And an other policy "OTH-ACT-003" starting today ending 1 year from today for that customer
    When I visit the other lifecycle customer show page
    And I expand the customer section "Expired Policy"
    Then "OTH-ACT-003" should NOT be visible in the other Expired Policy section

  Scenario: Expired and renewed other policy appears under Past Policy
    Given an other lifecycle customer exists with mobile "9705002001"
    And an other policy "OTH-P2-EXP" that expired 2 years ago and has been renewed for that customer
    And an other renewal policy "OTH-P3-REN" replacing "OTH-P2-EXP" for that customer
    When I visit the other lifecycle customer show page
    And I expand the customer section "Past Policy"
    Then "OTH-P2-EXP" should be visible in the other Past Policy section

  Scenario: Expired and renewed other policy does NOT appear under Expired Policy
    Given an other lifecycle customer exists with mobile "9705002002"
    And an other policy "OTH-P2B-EXP" that expired 2 years ago and has been renewed for that customer
    And an other renewal policy "OTH-P3B-REN" replacing "OTH-P2B-EXP" for that customer
    When I visit the other lifecycle customer show page
    And I expand the customer section "Expired Policy"
    Then "OTH-P2B-EXP" should NOT be visible in the other Expired Policy section

  Scenario: Other renewal policy appears as Active
    Given an other lifecycle customer exists with mobile "9705002003"
    And an other policy "OTH-P2C-EXP" that expired 2 years ago and has been renewed for that customer
    And an other renewal policy "OTH-P3C-REN" replacing "OTH-P2C-EXP" for that customer
    When I visit the other lifecycle customer show page
    Then the Active Policies count should be at least 1
    And "OTH-P3C-REN" should be visible in the Other Insurance section

  Scenario: Expired and NOT renewed other policy appears under Expired Policy
    Given an other lifecycle customer exists with mobile "9705003001"
    And an other policy "OTH-P4-NORENEW" that expired 2 years ago and has NOT been renewed for that customer
    When I visit the other lifecycle customer show page
    And I expand the customer section "Expired Policy"
    Then "OTH-P4-NORENEW" should be visible in the other Expired Policy section

  Scenario: Expired and NOT renewed other policy does NOT appear under Past Policy
    Given an other lifecycle customer exists with mobile "9705003002"
    And an other policy "OTH-P4B-NORENEW" that expired 2 years ago and has NOT been renewed for that customer
    When I visit the other lifecycle customer show page
    And I expand the customer section "Past Policy"
    Then "OTH-P4B-NORENEW" should NOT be visible in the other Past Policy section

  Scenario: Full lifecycle — 4 other insurance policies yield correct section counts
    Given an other lifecycle customer exists with mobile "9705004001"
    And an other policy "OTH-FULL-P1" starting today ending 1 year from today for that customer
    And an other policy "OTH-FULL-P2" that expired 2 years ago and has been renewed for that customer
    And an other renewal policy "OTH-FULL-P3" replacing "OTH-FULL-P2" for that customer
    And an other policy "OTH-FULL-P4" that expired 2 years ago and has NOT been renewed for that customer
    When I visit the other lifecycle customer show page
    Then the Active Policies count should be 2
    And the Past Policies count should be 1
    And the Expired Policies count should be 1

  # ═══════════════════════════════════════════════════════════════════════════
  # CREATE — INSURANCE TYPES
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Create Travel Insurance policy
    Given I am on the new other insurance page
    When I fill in the other insurance form with mandatory fields:
      | field          | value             |
      | Policy Number  | OTH-TRAV-001      |
      | Insurance Type | Travel Insurance  |
      | Net Premium    | 5000              |
    And I select customer "Test Client" from the other client dropdown
    And I select other insurance company "LIC of India"
    And I select other policy type "New"
    And I set other policy start date to today
    And I set other policy end date to 1 year from today
    And I click "Create General Insurance"
    Then I should see "successfully created"
    And I should see "OTH-TRAV-001"

  Scenario: Create Home Insurance policy
    Given I am on the new other insurance page
    When I fill in the other insurance form with mandatory fields:
      | field          | value          |
      | Policy Number  | OTH-HOME-001   |
      | Insurance Type | Home Insurance |
      | Net Premium    | 8000           |
    And I select customer "Test Client" from the other client dropdown
    And I select other insurance company "LIC of India"
    And I select other policy type "New"
    And I set other policy start date to today
    And I set other policy end date to 1 year from today
    And I click "Create General Insurance"
    Then I should see "successfully created"

  Scenario: Create Personal Accident Insurance policy
    Given I am on the new other insurance page
    When I fill in the other insurance form with mandatory fields:
      | field          | value                       |
      | Policy Number  | OTH-PA-001                  |
      | Insurance Type | Personal Accident Insurance |
      | Net Premium    | 3000                        |
    And I select customer "Test Client" from the other client dropdown
    And I select other insurance company "LIC of India"
    And I select other policy type "New"
    And I set other policy start date to today
    And I set other policy end date to 1 year from today
    And I click "Create General Insurance"
    Then I should see "successfully created"

  Scenario: Create Renewal type other insurance
    Given I am on the new other insurance page
    When I fill in the other insurance form with mandatory fields:
      | field          | value            |
      | Policy Number  | OTH-REN-001      |
      | Insurance Type | Travel Insurance |
      | Net Premium    | 5500             |
    And I select customer "Test Client" from the other client dropdown
    And I select other insurance company "LIC of India"
    And I select other policy type "Renewal"
    And I set other policy start date to today
    And I set other policy end date to 1 year from today
    And I click "Create General Insurance"
    Then I should see "successfully created"

  # ═══════════════════════════════════════════════════════════════════════════
  # CREATE — VALIDATION
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Validation — submitting empty other insurance form shows errors
    Given I am on the new other insurance page
    When I click "Create General Insurance" without filling any fields
    Then I should see other insurance validation errors

  # ═══════════════════════════════════════════════════════════════════════════
  # VIEW — LIST PAGE
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Other insurance list page loads
    When I visit the other insurance list page
    Then I should see the other insurance list page

  Scenario: List page shows policy number
    Given an other insurance policy for view exists with number "OTH-LIST-001"
    When I visit the other insurance list page
    Then I should see "OTH-LIST-001"

  Scenario: List page shows action buttons
    Given an other insurance policy for view exists with number "OTH-LIST-ACT-01"
    When I visit the other insurance list page
    Then I should see other insurance list action buttons

  Scenario: List page shows status for current policy
    Given an other insurance policy for view exists with number "OTH-LIST-STS-01"
    When I visit the other insurance list page
    Then I should see "Active"

  # ═══════════════════════════════════════════════════════════════════════════
  # VIEW — SHOW PAGE (DETAIL)
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Show page is accessible for an other insurance policy
    Given an other insurance policy for view exists with number "OTH-SHOW-001"
    When I visit the other insurance show page for "OTH-SHOW-001"
    Then I should be on the other insurance show page
    And I should see "OTH-SHOW-001"

  Scenario: Show page displays insurance company
    Given an other insurance policy for view exists with number "OTH-SHOW-002"
    When I visit the other insurance show page for "OTH-SHOW-002"
    Then I should see "LIC of India"

  Scenario: Show page displays insurance type
    Given an other insurance policy for view exists with number "OTH-SHOW-003"
    When I visit the other insurance show page for "OTH-SHOW-003"
    Then I should see other insurance type on show page

  Scenario: Show page displays premium details
    Given an other insurance policy for view exists with number "OTH-SHOW-004"
    When I visit the other insurance show page for "OTH-SHOW-004"
    Then I should see other insurance premium details on show page

  Scenario: Show page has Edit button
    Given an other insurance policy for view exists with number "OTH-SHOW-005"
    When I visit the other insurance show page for "OTH-SHOW-005"
    Then I should see other insurance edit link on show page

  # ═══════════════════════════════════════════════════════════════════════════
  # EDIT
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Edit other insurance — update net premium
    Given an other insurance policy for edit exists with number "OTH-EDIT-001"
    When I navigate to edit other insurance "OTH-EDIT-001"
    And I update the other insurance net premium to "7000"
    And I submit the other insurance edit form
    Then I should see other insurance updated successfully

  Scenario: Edit other insurance — change policy type to Renewal
    Given an other insurance policy for edit exists with number "OTH-EDIT-002"
    When I navigate to edit other insurance "OTH-EDIT-002"
    And I update the other insurance policy type to "Renewal"
    And I submit the other insurance edit form
    Then I should see other insurance updated successfully

  Scenario: Edit other insurance — update insurance type
    Given an other insurance policy for edit exists with number "OTH-EDIT-003"
    When I navigate to edit other insurance "OTH-EDIT-003"
    And I update the other insurance type to "Home Insurance"
    And I submit the other insurance edit form
    Then I should see other insurance updated successfully

  # ═══════════════════════════════════════════════════════════════════════════
  # DELETE
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Delete other insurance policy from show page
    Given an other insurance policy for edit exists with number "OTH-DEL-001"
    When I visit the other insurance show page for "OTH-DEL-001"
    And I delete the other insurance from the show page
    Then I should see other insurance deleted successfully

  Scenario: Deleted other insurance disappears from list
    Given an other insurance policy for edit exists with number "OTH-DEL-002"
    When I delete other insurance "OTH-DEL-002" from the list page
    Then other insurance "OTH-DEL-002" should not appear in the list

  # ═══════════════════════════════════════════════════════════════════════════
  # RENEWAL WORKFLOW
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Policy eligible for renewal shows Renew button
    Given an other insurance policy exists and is eligible for renewal
    When I click "Renew" on that other insurance policy
    Then I should be on the new other insurance page prefilled with renewal data
