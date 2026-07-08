@javascript
Feature: User Management
  As an admin
  I want to manage users and agents
  So that I can control who has access to the system

  Background:
    Given I am logged in as admin
    And test prerequisites exist

  # ─── SIDEBAR NAVIGATION ──────────────────────────────────────────────────────

  Scenario: Users link in sidebar navigates to users list
    When I click sidebar link "Users"
    Then the URL should include "/admin/settings/user_roles"

  # ═══════════════════════════════════════════════════════════════════════════
  # CREATE USER
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Create user with compulsory fields only
    Given I am on the new user page
    When I fill in the user form with:
      | field     | value                  |
      | First Name | Vikram                |
      | Last Name  | Nair                  |
      | Mobile     | 9811001100            |
      | Email      | vikram.nair@test.com  |
      | User Type  | admin                 |
      | Password   | Password@123          |
    And I submit the user form
    Then I should see "User was successfully created"
    And I should see "Vikram Nair"

  Scenario: Create agent user with all fields
    Given I am on the new user page
    When I fill in the user form with:
      | field      | value                   |
      | First Name | Pradeep                 |
      | Last Name  | Kumar                   |
      | Mobile     | 9811002200              |
      | Email      | pradeep.kumar@test.com  |
      | User Type  | agent                   |
      | Password   | Password@123            |
    And I submit the user form
    Then I should see "User was successfully created"
    And I should see "Pradeep Kumar"

  Scenario: Validation error when first name is missing
    Given I am on the new user page
    When I fill in the user form with:
      | field     | value                 |
      | Last Name | Missing               |
      | Mobile    | 9811003300            |
      | Email     | missing.fn@test.com   |
      | User Type | admin                 |
      | Password  | Password@123          |
    And I submit the user form
    Then I should see user validation error for "First name"

  Scenario: Validation error when last name is missing
    Given I am on the new user page
    When I fill in the user form with:
      | field      | value               |
      | First Name | MissingLast         |
      | Mobile     | 9811004400          |
      | Email      | missing.ln@test.com |
      | User Type  | admin               |
      | Password   | Password@123        |
    And I submit the user form
    Then I should see user validation error for "Last name"

  Scenario: Validation error when email is missing
    Given I am on the new user page
    When I fill in the user form with:
      | field      | value        |
      | First Name | NoEmail      |
      | Last Name  | User         |
      | Mobile     | 9811005500   |
      | User Type  | admin        |
      | Password   | Password@123 |
    And I submit the user form
    Then I should see user validation error for "Email"

  Scenario: Validation error when mobile is missing
    Given I am on the new user page
    When I fill in the user form with:
      | field      | value                  |
      | First Name | NoMobile               |
      | Last Name  | User                   |
      | Email      | nomobile.user@test.com |
      | User Type  | admin                  |
      | Password   | Password@123           |
    And I submit the user form
    Then I should see user validation error for "Mobile"

  Scenario: Duplicate email shows validation error
    Given a user exists with email "duplicate@test.com" and mobile "9811006600"
    And I am on the new user page
    When I fill in the user form with:
      | field      | value              |
      | First Name | Duplicate          |
      | Last Name  | Email              |
      | Mobile     | 9811007700         |
      | Email      | duplicate@test.com |
      | User Type  | admin              |
      | Password   | Password@123       |
    And I submit the user form
    Then I should see user duplicate email error

  Scenario: Duplicate mobile shows validation error
    Given a user exists with email "other@test.com" and mobile "9811008800"
    And I am on the new user page
    When I fill in the user form with:
      | field      | value          |
      | First Name | Duplicate      |
      | Last Name  | Mobile         |
      | Mobile     | 9811008800     |
      | Email      | new@test.com   |
      | User Type  | admin          |
      | Password   | Password@123   |
    And I submit the user form
    Then I should see user duplicate mobile error

  # ═══════════════════════════════════════════════════════════════════════════
  # VIEW LISTING PAGE
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: User list shows the user record
    Given a user exists with email "list.view@test.com" and mobile "9811009900"
    When I visit the users list page
    Then I should see "list.view@test.com"

  Scenario: User list displays total count
    Given a user exists with email "count.test@test.com" and mobile "9811011100"
    When I visit the users list page
    Then I should see user list total count

  Scenario: User list shows view and edit action buttons
    Given a user exists with email "actions.test@test.com" and mobile "9811022200"
    When I visit the users list page
    Then I should see user list action buttons

  Scenario: User list shows status information
    Given a user exists with email "status.test@test.com" and mobile "9811033300"
    When I visit the users list page
    Then I should see user status on the list

  # ═══════════════════════════════════════════════════════════════════════════
  # VIEW USER DETAILS
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: View user details page is accessible
    Given a user exists with name "Show User" email "show.user@test.com" and mobile "9811044400"
    When I click view on user "Show User"
    Then I should be on the user show page
    And I should see "Show User"

  Scenario: User show page displays user name
    Given a user exists with name "Detail User" email "detail.user@test.com" and mobile "9811055500"
    When I click view on user "Detail User"
    Then I should see "Detail User"

  Scenario: User show page displays account information
    Given a user exists with name "Account Info" email "acct.info@test.com" and mobile "9811066600"
    When I click view on user "Account Info"
    Then I should see "Account Information"

  # ═══════════════════════════════════════════════════════════════════════════
  # EDIT USER
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Edit user first name
    Given a user exists with name "Edit First" email "edit.first@test.com" and mobile "9811077700"
    When I click edit on user "Edit First"
    And I update the user first name to "FirstEdited"
    And I submit the user form
    Then I should see "User was successfully updated"
    And I should see "FirstEdited"

  Scenario: Edit user last name
    Given a user exists with name "Edit Last" email "edit.last@test.com" and mobile "9811088800"
    When I click edit on user "Edit Last"
    And I update the user last name to "LastEdited"
    And I submit the user form
    Then I should see "User was successfully updated"
    And I should see "LastEdited"

  Scenario: Edit user email
    Given a user exists with name "Edit Email" email "edit.email@test.com" and mobile "9811099900"
    When I click edit on user "Edit Email"
    And I update the user email to "editemail.updated@test.com"
    And I submit the user form
    Then I should see "User was successfully updated"

  Scenario: Clearing mandatory field shows validation error on edit
    Given a user exists with name "Clear Field" email "clear.field@test.com" and mobile "9811111100"
    When I click edit on user "Clear Field"
    And I clear the user first name
    And I submit the user form
    Then I should see user validation error for "First name"

  # ═══════════════════════════════════════════════════════════════════════════
  # DELETE USER
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Delete a user from the list
    Given a user exists with name "Delete Me" email "deleteme@test.com" and mobile "9811222200"
    When I visit the users list page
    And I delete user "Delete Me"
    Then I should not see "deleteme@test.com" on the users page

  Scenario: Delete shows success message
    Given a user exists with name "Delete Confirm" email "deleteconfirm@test.com" and mobile "9811333300"
    When I visit the users list page
    And I delete user "Delete Confirm"
    Then I should see "User was successfully deleted"
