@javascript
Feature: Role Management
  As an admin
  I want to manage roles and their permissions
  So that I can control what each user type can do in the system

  Background:
    Given I am logged in as admin
    And test prerequisites exist

  # ─── SIDEBAR NAVIGATION ──────────────────────────────────────────────────────

  Scenario: Roles link in sidebar navigates to roles list
    When I click sidebar link "Roles"
    Then the URL should include "/admin/roles"

  # ═══════════════════════════════════════════════════════════════════════════
  # CREATE ROLE
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Create a new role with name only
    Given I am on the new role page
    When I fill in the role form with:
      | field  | value           |
      | Name   | Customer Support |
    And I submit the role form
    Then I should see role created successfully

  Scenario: Create a new role with name and description
    Given I am on the new role page
    When I fill in the role form with:
      | field       | value                             |
      | Name        | Sales Manager                     |
      | Description | Manages sales team and leads      |
    And I submit the role form
    Then I should see role created successfully
    And I should see "Sales Manager"

  Scenario: Validation error when role name is missing
    Given I am on the new role page
    When I fill in the role form with:
      | field       | value                   |
      | Description | No name role description |
    And I submit the role form
    Then I should see role name validation error

  Scenario: Validation error for duplicate role name
    Given a role exists with name "Duplicate Role"
    And I am on the new role page
    When I fill in the role form with:
      | field | value          |
      | Name  | Duplicate Role |
    And I submit the role form
    Then I should see role duplicate name error

  # ═══════════════════════════════════════════════════════════════════════════
  # VIEW LISTING PAGE
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Role list shows the role record
    Given a role exists with name "List View Role"
    When I visit the roles list page
    Then I should see "List View Role"

  Scenario: Role list shows view and edit action buttons
    Given a role exists with name "Actions Role"
    When I visit the roles list page
    Then I should see role list action buttons

  Scenario: Role list shows status badge for each role
    Given a role exists with name "Status Role"
    When I visit the roles list page
    Then I should see role status badge

  Scenario: Role list shows total count
    Given a role exists with name "Count Role"
    When I visit the roles list page
    Then I should see roles list heading

  # ═══════════════════════════════════════════════════════════════════════════
  # VIEW ROLE DETAILS
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: View role details page is accessible
    Given a role exists with name "Show Detail Role"
    When I click view on role "Show Detail Role"
    Then I should be on the role show page
    And I should see "Show Detail Role"

  Scenario: Role show page displays role information
    Given a role exists with name "Info Display Role"
    When I click view on role "Info Display Role"
    Then I should see "Info Display Role"

  Scenario: Role show page with description displays it correctly
    Given a role exists with name "Desc Role" and description "Handles customer queries"
    When I click view on role "Desc Role"
    Then I should see "Handles customer queries"

  # ═══════════════════════════════════════════════════════════════════════════
  # EDIT ROLE
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Edit role name
    Given a role exists with name "Edit Me Role"
    When I click edit on role "Edit Me Role"
    And I update the role name to "Edited Role Name"
    And I submit the role form
    Then I should see role updated successfully
    And I should see "Edited Role Name"

  Scenario: Edit role description
    Given a role exists with name "Edit Desc Role"
    When I click edit on role "Edit Desc Role"
    And I update the role description to "Updated description text"
    And I submit the role form
    Then I should see role updated successfully

  Scenario: Clearing role name shows validation error on edit
    Given a role exists with name "Clear Name Role"
    When I click edit on role "Clear Name Role"
    And I clear the role name
    And I submit the role form
    Then I should see role name validation error

  # ═══════════════════════════════════════════════════════════════════════════
  # TOGGLE STATUS
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Active role can be deactivated
    Given an active role exists with name "Active Toggle Role"
    When I visit the roles list page
    And I toggle the status of role "Active Toggle Role"
    Then I should see role status changed

  # ═══════════════════════════════════════════════════════════════════════════
  # DELETE ROLE
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Delete a role with no users
    Given a role exists with name "Delete Me Role"
    When I visit the roles list page
    And I delete role "Delete Me Role"
    Then I should not see "Delete Me Role" on the roles page

  Scenario: Delete role shows success message
    Given a role exists with name "Delete Confirm Role"
    When I visit the roles list page
    And I delete role "Delete Confirm Role"
    Then I should see role deleted successfully
