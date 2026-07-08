@javascript
Feature: Health Insurance — Comprehensive Policy Management and Lifecycle
  As an admin
  I want to manage health insurance policies end-to-end
  So that Active, Past (Renewed) and Expired policies are correctly categorised
  and all CRUD operations behave as expected

  Background:
    Given I am logged in as admin
    And test prerequisites exist

  # ═══════════════════════════════════════════════════════════════════════════
  # SIDEBAR NAVIGATION
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Health Insurance link in sidebar navigates to list
    When I click sidebar link "Health Insurance"
    Then the URL should include "/admin/insurance/health"

  # ═══════════════════════════════════════════════════════════════════════════
  # POLICY LIFECYCLE — BUSINESS RULES
  #
  # Rule 1:  active?  (end_date >= today)             → Active Policies
  # Rule 2:  expired + is_renewed = true              → Past Policy (Renewed)
  # Rule 3:  expired + is_renewed = false             → Expired Policy (Not Renewed)
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Active health policy appears in Active Policies section
    Given a health lifecycle customer exists with mobile "9703001001"
    And a health policy "HLTH-ACT-001" starting today ending 1 year from today for that customer
    When I visit the health lifecycle customer show page
    Then the Active Policies count should be at least 1
    And "HLTH-ACT-001" should be visible in the Health Insurance section

  Scenario: Active health policy does NOT appear under Past Policy
    Given a health lifecycle customer exists with mobile "9703001002"
    And a health policy "HLTH-ACT-002" starting today ending 1 year from today for that customer
    When I visit the health lifecycle customer show page
    And I expand the customer section "Past Policy"
    Then "HLTH-ACT-002" should NOT be visible in the health Past Policy section

  Scenario: Active health policy does NOT appear under Expired Policy
    Given a health lifecycle customer exists with mobile "9703001003"
    And a health policy "HLTH-ACT-003" starting today ending 1 year from today for that customer
    When I visit the health lifecycle customer show page
    And I expand the customer section "Expired Policy"
    Then "HLTH-ACT-003" should NOT be visible in the health Expired Policy section

  Scenario: Expired and renewed health policy appears under Past Policy
    Given a health lifecycle customer exists with mobile "9703002001"
    And a health policy "HLTH-P2-EXP" that expired 2 years ago and has been renewed for that customer
    And a health renewal policy "HLTH-P3-REN" replacing "HLTH-P2-EXP" for that customer
    When I visit the health lifecycle customer show page
    And I expand the customer section "Past Policy"
    Then "HLTH-P2-EXP" should be visible in the health Past Policy section

  Scenario: Expired and renewed health policy does NOT appear under Expired Policy
    Given a health lifecycle customer exists with mobile "9703002002"
    And a health policy "HLTH-P2B-EXP" that expired 2 years ago and has been renewed for that customer
    And a health renewal policy "HLTH-P3B-REN" replacing "HLTH-P2B-EXP" for that customer
    When I visit the health lifecycle customer show page
    And I expand the customer section "Expired Policy"
    Then "HLTH-P2B-EXP" should NOT be visible in the health Expired Policy section

  Scenario: Renewal health policy appears as Active
    Given a health lifecycle customer exists with mobile "9703002003"
    And a health policy "HLTH-P2C-EXP" that expired 2 years ago and has been renewed for that customer
    And a health renewal policy "HLTH-P3C-REN" replacing "HLTH-P2C-EXP" for that customer
    When I visit the health lifecycle customer show page
    Then the Active Policies count should be at least 1
    And "HLTH-P3C-REN" should be visible in the Health Insurance section

  Scenario: Expired and NOT renewed health policy appears under Expired Policy
    Given a health lifecycle customer exists with mobile "9703003001"
    And a health policy "HLTH-P4-NORENEW" that expired 2 years ago and has NOT been renewed for that customer
    When I visit the health lifecycle customer show page
    And I expand the customer section "Expired Policy"
    Then "HLTH-P4-NORENEW" should be visible in the health Expired Policy section

  Scenario: Expired and NOT renewed health policy does NOT appear under Past Policy
    Given a health lifecycle customer exists with mobile "9703003002"
    And a health policy "HLTH-P4B-NORENEW" that expired 2 years ago and has NOT been renewed for that customer
    When I visit the health lifecycle customer show page
    And I expand the customer section "Past Policy"
    Then "HLTH-P4B-NORENEW" should NOT be visible in the health Past Policy section

  Scenario: Full lifecycle — 4 health policies yield correct section counts
    Given a health lifecycle customer exists with mobile "9703004001"
    And a health policy "HLTH-FULL-P1" starting today ending 1 year from today for that customer
    And a health policy "HLTH-FULL-P2" that expired 2 years ago and has been renewed for that customer
    And a health renewal policy "HLTH-FULL-P3" replacing "HLTH-FULL-P2" for that customer
    And a health policy "HLTH-FULL-P4" that expired 2 years ago and has NOT been renewed for that customer
    When I visit the health lifecycle customer show page
    Then the Active Policies count should be 2
    And the Past Policies count should be 1
    And the Expired Policies count should be 1

  # ═══════════════════════════════════════════════════════════════════════════
  # CREATE — MANDATORY FIELDS
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Create health insurance with mandatory fields only
    Given I am on the new health insurance page
    When I fill in the health insurance form with all fields:
      | field         | value            |
      | Policy Number | HLTH-COMP-001    |
      | Net Premium   | 25000            |
      | GST %         | 18               |
    And I select customer "Test Client" from the health client dropdown
    And I select health insurance type "Individual"
    And I select health policy type "New"
    And I select health insurance company "LIC of India"
    And I select health payment mode "Yearly"
    And I set health policy booking date to today
    And I set health policy start date to today
    And I set health policy end date to 1 year from today
    And I set health sum insured to "5 lakhs"
    And I click "Create Policy"
    Then I should see "Health insurance policy was successfully created"
    And I should see "HLTH-COMP-001"

  Scenario: Create Family Floater health insurance
    Given I am on the new health insurance page
    When I fill in the health insurance form with all fields:
      | field         | value            |
      | Policy Number | HLTH-FAM-COMP-01 |
      | Net Premium   | 35000            |
      | GST %         | 18               |
    And I select customer "Test Client" from the health client dropdown
    And I select health insurance type "Family Floater"
    And I select health policy type "New"
    And I select health insurance company "LIC of India"
    And I select health payment mode "Yearly"
    And I set health policy booking date to today
    And I set health policy start date to today
    And I set health policy end date to 1 year from today
    And I set health sum insured to "10 lakhs"
    And I click "Create Policy"
    Then I should see "Health insurance policy was successfully created"

  Scenario: Create Group health insurance
    Given I am on the new health insurance page
    When I fill in the health insurance form with all fields:
      | field         | value            |
      | Policy Number | HLTH-GRP-COMP-01 |
      | Net Premium   | 50000            |
      | GST %         | 18               |
    And I select customer "Test Client" from the health client dropdown
    And I select health insurance type "Group"
    And I select health policy type "New"
    And I select health insurance company "LIC of India"
    And I select health payment mode "Yearly"
    And I set health policy booking date to today
    And I set health policy start date to today
    And I set health policy end date to 1 year from today
    And I set health sum insured to "25 lakhs"
    And I click "Create Policy"
    Then I should see "Health insurance policy was successfully created"

  Scenario: Create Renewal type health insurance
    Given I am on the new health insurance page
    When I fill in the health insurance form with all fields:
      | field         | value            |
      | Policy Number | HLTH-REN-COMP-01 |
      | Net Premium   | 28000            |
      | GST %         | 18               |
    And I select customer "Test Client" from the health client dropdown
    And I select health insurance type "Individual"
    And I select health policy type "Renewal"
    And I select health insurance company "LIC of India"
    And I select health payment mode "Yearly"
    And I set health policy booking date to today
    And I set health policy start date to today
    And I set health policy end date to 1 year from today
    And I set health sum insured to "5 lakhs"
    And I click "Create Policy"
    Then I should see "Health insurance policy was successfully created"

  Scenario: Create Porting type health insurance
    Given I am on the new health insurance page
    When I fill in the health insurance form with all fields:
      | field         | value            |
      | Policy Number | HLTH-PORT-COMP01 |
      | Net Premium   | 22000            |
      | GST %         | 18               |
    And I select customer "Test Client" from the health client dropdown
    And I select health insurance type "Individual"
    And I select health policy type "Porting"
    And I select health insurance company "LIC of India"
    And I select health payment mode "Yearly"
    And I set health policy booking date to today
    And I set health policy start date to today
    And I set health policy end date to 1 year from today
    And I set health sum insured to "5 lakhs"
    And I click "Create Policy"
    Then I should see "Health insurance policy was successfully created"

  # ═══════════════════════════════════════════════════════════════════════════
  # CREATE — PAYMENT MODES
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario Outline: Create health insurance with different payment modes
    Given I am on the new health insurance page
    When I fill in the health insurance form with all fields:
      | field         | value              |
      | Policy Number | HLTH-PM-<mode>-001 |
      | Net Premium   | 20000              |
      | GST %         | 18                 |
    And I select customer "Test Client" from the health client dropdown
    And I select health insurance type "Individual"
    And I select health policy type "New"
    And I select health insurance company "LIC of India"
    And I select health payment mode "<mode>"
    And I set health policy booking date to today
    And I set health policy start date to today
    And I set health policy end date to 1 year from today
    And I set health sum insured to "3 lakhs"
    And I click "Create Policy"
    Then I should see "Health insurance policy was successfully created"

    Examples:
      | mode       |
      | Yearly     |
      | Half Yearly|
      | Quarterly  |
      | Monthly    |
      | Single     |

  # ═══════════════════════════════════════════════════════════════════════════
  # CREATE — VALIDATION
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Validation — submitting empty health form shows errors
    Given I am on the new health insurance page
    When I click "Create Policy" without filling any fields
    Then I should see health insurance validation errors

  # ═══════════════════════════════════════════════════════════════════════════
  # VIEW — LIST PAGE
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Health insurance list page loads with policies
    Given I have multiple health insurance policies
    When I visit the health insurance list page
    Then I should see health insurance policies listed

  Scenario: List page shows policy number
    Given a health insurance policy for view exists with number "HLTH-LIST-001"
    When I visit the health insurance list page
    Then I should see "HLTH-LIST-001"

  Scenario: List page shows action buttons
    Given a health insurance policy for view exists with number "HLTH-LIST-ACT-01"
    When I visit the health insurance list page
    Then I should see health insurance list action buttons

  Scenario: List page shows Active status for a current policy
    Given a health insurance policy for view exists with number "HLTH-LIST-STS-01"
    When I visit the health insurance list page
    Then I should see "Active"

  # ═══════════════════════════════════════════════════════════════════════════
  # VIEW — SHOW PAGE (DETAIL)
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Show page is accessible for a health insurance policy
    Given a health insurance policy for view exists with number "HLTH-SHOW-001"
    When I visit the health insurance show page for "HLTH-SHOW-001"
    Then I should be on the health insurance show page
    And I should see "HLTH-SHOW-001"

  Scenario: Show page displays insurance company name
    Given a health insurance policy for view exists with number "HLTH-SHOW-002"
    When I visit the health insurance show page for "HLTH-SHOW-002"
    Then I should see "LIC of India"

  Scenario: Show page displays premium information
    Given a health insurance policy for view exists with number "HLTH-SHOW-003"
    When I visit the health insurance show page for "HLTH-SHOW-003"
    Then I should see health insurance premium details on show page

  Scenario: Show page displays policy type
    Given a health insurance policy for view exists with number "HLTH-SHOW-004"
    When I visit the health insurance show page for "HLTH-SHOW-004"
    Then I should see health insurance policy type on show page

  Scenario: Show page has Edit button
    Given a health insurance policy for view exists with number "HLTH-SHOW-005"
    When I visit the health insurance show page for "HLTH-SHOW-005"
    Then I should see health insurance edit link on show page

  # ═══════════════════════════════════════════════════════════════════════════
  # EDIT
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Edit health insurance — update net premium
    Given a health insurance policy for edit exists with number "HLTH-EDIT-001"
    When I navigate to edit health insurance "HLTH-EDIT-001"
    And I update the health insurance net premium to "30000"
    And I submit the health insurance edit form
    Then I should see health insurance updated successfully

  Scenario: Edit health insurance — change payment mode
    Given a health insurance policy for edit exists with number "HLTH-EDIT-002"
    When I navigate to edit health insurance "HLTH-EDIT-002"
    And I update the health insurance payment mode to "Half Yearly"
    And I submit the health insurance edit form
    Then I should see health insurance updated successfully

  Scenario: Edit health insurance — update plan name
    Given a health insurance policy for edit exists with number "HLTH-EDIT-003"
    When I navigate to edit health insurance "HLTH-EDIT-003"
    And I update the health insurance plan name to "Star Comprehensive Plan"
    And I submit the health insurance edit form
    Then I should see health insurance updated successfully

  Scenario: Edit health insurance — change insurance type to Family Floater
    Given a health insurance policy for edit exists with number "HLTH-EDIT-004"
    When I navigate to edit health insurance "HLTH-EDIT-004"
    And I update the health insurance type to "Family Floater"
    And I submit the health insurance edit form
    Then I should see health insurance updated successfully

  # ═══════════════════════════════════════════════════════════════════════════
  # DELETE
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Delete health insurance policy from show page
    Given a health insurance policy for edit exists with number "HLTH-DEL-001"
    When I visit the health insurance show page for "HLTH-DEL-001"
    And I delete the health insurance from the show page
    Then I should see health insurance deleted successfully

  Scenario: Deleted health insurance disappears from list
    Given a health insurance policy for edit exists with number "HLTH-DEL-002"
    When I delete health insurance "HLTH-DEL-002" from the list page
    Then health insurance "HLTH-DEL-002" should not appear in the list

  # ═══════════════════════════════════════════════════════════════════════════
  # RENEWAL WORKFLOW
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Policy eligible for renewal shows Renew button
    Given a health insurance policy "HEALTH-ORIG-COMP-001" exists and is eligible for renewal
    When I click "Renew" on that health policy
    Then I should be on the new health insurance page prefilled with renewal data
