@javascript
Feature: Motor Insurance — Comprehensive Policy Management and Lifecycle
  As an admin
  I want to manage motor insurance policies end-to-end
  So that Active, Past (Renewed) and Expired policies are correctly categorised
  and all CRUD operations behave as expected

  Background:
    Given I am logged in as admin
    And test prerequisites exist

  # ═══════════════════════════════════════════════════════════════════════════
  # SIDEBAR NAVIGATION
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Motor Insurance link in sidebar navigates to list
    When I click sidebar link "Motor Insurance"
    Then the URL should include "/admin/insurance/motor"

  # ═══════════════════════════════════════════════════════════════════════════
  # POLICY LIFECYCLE — BUSINESS RULES
  #
  # Rule 1:  active?  (end_date >= today)                            → Active Policies
  # Rule 2:  expired + renewal policy exists for same vehicle        → Past Policy (Renewed)
  # Rule 3:  expired + no renewal policy for same vehicle            → Expired Policy (Not Renewed)
  #
  # Motor uses DB query for has_been_renewed? (not is_renewed column):
  #   — A policy is "renewed" when another motor policy exists with
  #     same customer_id, same registration_number, type='Renewal',
  #     and start_date > original.end_date
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Active motor policy appears in Active Policies section
    Given a motor lifecycle customer exists with mobile "9704001001"
    And a motor policy "MOT-ACT-001" for vehicle "MH01AA1001" starting today ending 1 year from today for that customer
    When I visit the motor lifecycle customer show page
    Then the Active Policies count should be at least 1
    And "MOT-ACT-001" should be visible in the Motor Insurance section

  Scenario: Active motor policy does NOT appear under Past Policy
    Given a motor lifecycle customer exists with mobile "9704001002"
    And a motor policy "MOT-ACT-002" for vehicle "MH01AA1002" starting today ending 1 year from today for that customer
    When I visit the motor lifecycle customer show page
    And I expand the customer section "Past Policy"
    Then "MOT-ACT-002" should NOT be visible in the motor Past Policy section

  Scenario: Active motor policy does NOT appear under Expired Policy
    Given a motor lifecycle customer exists with mobile "9704001003"
    And a motor policy "MOT-ACT-003" for vehicle "MH01AA1003" starting today ending 1 year from today for that customer
    When I visit the motor lifecycle customer show page
    And I expand the customer section "Expired Policy"
    Then "MOT-ACT-003" should NOT be visible in the motor Expired Policy section

  Scenario: Expired and renewed motor policy appears under Past Policy
    Given a motor lifecycle customer exists with mobile "9704002001"
    And a motor policy "MOT-P2-EXP" for vehicle "MH01BB2001" that expired 2 years ago for that customer
    And a motor renewal policy "MOT-P3-REN" for vehicle "MH01BB2001" replacing "MOT-P2-EXP" for that customer
    When I visit the motor lifecycle customer show page
    And I expand the customer section "Past Policy"
    Then "MOT-P2-EXP" should be visible in the motor Past Policy section

  Scenario: Expired and renewed motor policy does NOT appear under Expired Policy
    Given a motor lifecycle customer exists with mobile "9704002002"
    And a motor policy "MOT-P2B-EXP" for vehicle "MH01BB2002" that expired 2 years ago for that customer
    And a motor renewal policy "MOT-P3B-REN" for vehicle "MH01BB2002" replacing "MOT-P2B-EXP" for that customer
    When I visit the motor lifecycle customer show page
    And I expand the customer section "Expired Policy"
    Then "MOT-P2B-EXP" should NOT be visible in the motor Expired Policy section

  Scenario: Motor renewal policy appears as Active
    Given a motor lifecycle customer exists with mobile "9704002003"
    And a motor policy "MOT-P2C-EXP" for vehicle "MH01BB2003" that expired 2 years ago for that customer
    And a motor renewal policy "MOT-P3C-REN" for vehicle "MH01BB2003" replacing "MOT-P2C-EXP" for that customer
    When I visit the motor lifecycle customer show page
    Then the Active Policies count should be at least 1
    And "MOT-P3C-REN" should be visible in the Motor Insurance section

  Scenario: Expired and NOT renewed motor policy appears under Expired Policy
    Given a motor lifecycle customer exists with mobile "9704003001"
    And a motor policy "MOT-P4-NORENEW" for vehicle "MH01CC3001" that expired 2 years ago for that customer
    When I visit the motor lifecycle customer show page
    And I expand the customer section "Expired Policy"
    Then "MOT-P4-NORENEW" should be visible in the motor Expired Policy section

  Scenario: Expired and NOT renewed motor policy does NOT appear under Past Policy
    Given a motor lifecycle customer exists with mobile "9704003002"
    And a motor policy "MOT-P4B-NORENEW" for vehicle "MH01CC3002" that expired 2 years ago for that customer
    When I visit the motor lifecycle customer show page
    And I expand the customer section "Past Policy"
    Then "MOT-P4B-NORENEW" should NOT be visible in the motor Past Policy section

  Scenario: Full lifecycle — 4 motor policies yield correct section counts
    Given a motor lifecycle customer exists with mobile "9704004001"
    And a motor policy "MOT-FULL-P1" for vehicle "MH01DD4001" starting today ending 1 year from today for that customer
    And a motor policy "MOT-FULL-P2" for vehicle "MH01DD4002" that expired 2 years ago for that customer
    And a motor renewal policy "MOT-FULL-P3" for vehicle "MH01DD4002" replacing "MOT-FULL-P2" for that customer
    And a motor policy "MOT-FULL-P4" for vehicle "MH01DD4003" that expired 2 years ago for that customer
    When I visit the motor lifecycle customer show page
    Then the Active Policies count should be 2
    And the Past Policies count should be 1
    And the Expired Policies count should be 1

  # ═══════════════════════════════════════════════════════════════════════════
  # CREATE — VEHICLE TYPES
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Create motor insurance for Private Car — Old Vehicle
    Given I am on the new motor insurance page
    When I fill in the motor insurance form with mandatory fields:
      | field          | value          |
      | Policy Number  | MOT-COMP-001   |
      | Net Premium    | 15000          |
      | Vehicle Number | MH01AB0001     |
    And I select customer "Test Client" from the motor client dropdown
    And I select vehicle type "Old Vehicle"
    And I select class of vehicle "Private Car"
    And I select motor insurance type "Comprehensive"
    And I select motor insurance company "LIC of India"
    And I set motor policy booking date to today
    And I set motor policy start date to today
    And I set motor policy end date to 1 year from today
    And I click "Create Motor Insurance"
    Then I should see "Motor insurance policy was successfully created"
    And I should see "MOT-COMP-001"

  Scenario: Create motor insurance for New Vehicle
    Given I am on the new motor insurance page
    When I fill in the motor insurance form with mandatory fields:
      | field          | value          |
      | Policy Number  | MOT-COMP-002   |
      | Net Premium    | 18000          |
      | Vehicle Number | MH01AB0002     |
    And I select customer "Test Client" from the motor client dropdown
    And I select vehicle type "New Vehicle"
    And I select class of vehicle "Private Car"
    And I select motor insurance type "Comprehensive"
    And I select motor insurance company "LIC of India"
    And I set motor policy booking date to today
    And I set motor policy start date to today
    And I set motor policy end date to 1 year from today
    And I click "Create Motor Insurance"
    Then I should see "Motor insurance policy was successfully created"

  Scenario Outline: Create motor insurance for different vehicle classes
    Given I am on the new motor insurance page
    When I fill in the motor insurance form with mandatory fields:
      | field          | value              |
      | Policy Number  | MOT-CLS-<class>-01 |
      | Net Premium    | 12000              |
      | Vehicle Number | MH02CD0010         |
    And I select customer "Test Client" from the motor client dropdown
    And I select vehicle type "Old Vehicle"
    And I select class of vehicle "<class>"
    And I select motor insurance type "Comprehensive"
    And I select motor insurance company "LIC of India"
    And I set motor policy booking date to today
    And I set motor policy start date to today
    And I set motor policy end date to 1 year from today
    And I click "Create Motor Insurance"
    Then I should see "Motor insurance policy was successfully created"

    Examples:
      | class         |
      | Private Car   |
      | Two Wheeler   |
      | Goods Vehicle |
      | Taxi          |
      | Bus           |

  Scenario Outline: Create motor insurance with different coverage types
    Given I am on the new motor insurance page
    When I fill in the motor insurance form with mandatory fields:
      | field          | value             |
      | Policy Number  | MOT-<itype>-001   |
      | Net Premium    | 10000             |
      | Vehicle Number | MH03EF0020        |
    And I select customer "Test Client" from the motor client dropdown
    And I select vehicle type "Old Vehicle"
    And I select class of vehicle "Private Car"
    And I select motor insurance type "<itype>"
    And I select motor insurance company "LIC of India"
    And I set motor policy booking date to today
    And I set motor policy start date to today
    And I set motor policy end date to 1 year from today
    And I click "Create Motor Insurance"
    Then I should see "Motor insurance policy was successfully created"

    Examples:
      | itype         |
      | Comprehensive |
      | Third Party   |
      | Own Damage    |

  # ═══════════════════════════════════════════════════════════════════════════
  # CREATE — VALIDATION
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Validation — submitting empty motor form shows errors
    Given I am on the new motor insurance page
    When I click "Create Motor Insurance" without filling any fields
    Then I should see motor insurance validation errors

  # ═══════════════════════════════════════════════════════════════════════════
  # VIEW — LIST PAGE
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Motor insurance list page loads
    When I visit the motor insurance list page
    Then I should see the motor insurance list page

  Scenario: List page shows policy number
    Given a motor insurance policy for view exists with number "MOT-LIST-001"
    When I visit the motor insurance list page
    Then I should see "MOT-LIST-001"

  Scenario: List page shows action buttons
    Given a motor insurance policy for view exists with number "MOT-LIST-ACT-01"
    When I visit the motor insurance list page
    Then I should see motor insurance list action buttons

  Scenario: List page shows Active status for current policy
    Given a motor insurance policy for view exists with number "MOT-LIST-STS-01"
    When I visit the motor insurance list page
    Then I should see "Active"

  # ═══════════════════════════════════════════════════════════════════════════
  # VIEW — SHOW PAGE (DETAIL)
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Show page is accessible for a motor insurance policy
    Given a motor insurance policy for view exists with number "MOT-SHOW-001"
    When I visit the motor insurance show page for "MOT-SHOW-001"
    Then I should be on the motor insurance show page
    And I should see "MOT-SHOW-001"

  Scenario: Show page displays insurance company name
    Given a motor insurance policy for view exists with number "MOT-SHOW-002"
    When I visit the motor insurance show page for "MOT-SHOW-002"
    Then I should see "Bajaj Allianz General Insurance"

  Scenario: Show page displays vehicle registration number
    Given a motor insurance policy for view exists with number "MOT-SHOW-003"
    When I visit the motor insurance show page for "MOT-SHOW-003"
    Then I should see motor registration number on show page

  Scenario: Show page displays premium details
    Given a motor insurance policy for view exists with number "MOT-SHOW-004"
    When I visit the motor insurance show page for "MOT-SHOW-004"
    Then I should see motor insurance premium details on show page

  Scenario: Show page has Edit button
    Given a motor insurance policy for view exists with number "MOT-SHOW-005"
    When I visit the motor insurance show page for "MOT-SHOW-005"
    Then I should see motor insurance edit link on show page

  # ═══════════════════════════════════════════════════════════════════════════
  # EDIT
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Edit motor insurance — update net premium
    Given a motor insurance policy for edit exists with number "MOT-EDIT-001"
    When I navigate to edit motor insurance "MOT-EDIT-001"
    And I update the motor insurance net premium to "18000"
    And I submit the motor insurance edit form
    Then I should see motor insurance updated successfully

  Scenario: Edit motor insurance — change insurance type
    Given a motor insurance policy for edit exists with number "MOT-EDIT-002"
    When I navigate to edit motor insurance "MOT-EDIT-002"
    And I update the motor insurance type to "Third Party"
    And I submit the motor insurance edit form
    Then I should see motor insurance updated successfully

  Scenario: Edit motor insurance — add extra note
    Given a motor insurance policy for edit exists with number "MOT-EDIT-003"
    When I navigate to edit motor insurance "MOT-EDIT-003"
    And I update the motor insurance extra note to "Updated motor policy note"
    And I submit the motor insurance edit form
    Then I should see motor insurance updated successfully

  # ═══════════════════════════════════════════════════════════════════════════
  # DELETE
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Delete motor insurance policy from show page
    Given a motor insurance policy for edit exists with number "MOT-DEL-001"
    When I visit the motor insurance show page for "MOT-DEL-001"
    And I delete the motor insurance from the show page
    Then I should see motor insurance deleted successfully

  Scenario: Deleted motor insurance disappears from list
    Given a motor insurance policy for edit exists with number "MOT-DEL-002"
    When I delete motor insurance "MOT-DEL-002" from the list page
    Then motor insurance "MOT-DEL-002" should not appear in the list

  # ═══════════════════════════════════════════════════════════════════════════
  # RENEWAL WORKFLOW
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Policy eligible for renewal shows Renew button
    Given a motor insurance policy "MOTOR-ORIG-COMP-001" exists and is eligible for renewal
    When I click "Renew" on that motor policy
    Then I should be on the new motor insurance page prefilled with renewal data
