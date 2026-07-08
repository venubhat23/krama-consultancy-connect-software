@javascript
Feature: Ambassador Management
  As an admin
  I want to manage ambassadors (distributors)
  So that I can create, view, edit, deactivate, and delete ambassador records

  Background:
    Given I am logged in as admin
    And test prerequisites exist

  # ─── SIDEBAR NAVIGATION ────────────────────────────────────────────────────

  Scenario: Ambassadors link in sidebar navigates to ambassadors list
    When I click sidebar link "Ambassadors"
    Then the URL should include "/admin/distributors"
    And the page should load successfully

  Scenario: Sidebar Ambassadors link shows correct page heading
    When I click sidebar link "Ambassadors"
    Then I should see ambassador list heading

  # ─── CREATE: COMPULSORY FIELDS ─────────────────────────────────────────────

  Scenario: Create ambassador with only mandatory fields
    Given I am on the new ambassador page
    When I fill in the ambassador form with:
      | field      | value                    |
      | First Name | Kavitha                  |
      | Last Name  | Rao                      |
      | Mobile     | 9822200001               |
      | Email      | kavitha.rao@drwise.com   |
    And I submit the ambassador form
    Then I should see ambassador created successfully
    And I should see "Kavitha Rao"

  Scenario: Reject ambassador when First Name is missing
    Given I am on the new ambassador page
    When I fill in the ambassador form with:
      | field      | value                       |
      | Last Name  | Sharma                      |
      | Mobile     | 9822200011                  |
      | Email      | no.firstname.amb@drwise.com |
    And I submit the ambassador form
    Then I should see "First name can't be blank"

  Scenario: Reject ambassador when Last Name is missing
    Given I am on the new ambassador page
    When I fill in the ambassador form with:
      | field      | value                      |
      | First Name | Priya                      |
      | Mobile     | 9822200012                 |
      | Email      | no.lastname.amb@drwise.com |
    And I submit the ambassador form
    Then I should see "Last name can't be blank"

  Scenario: Reject ambassador when Mobile is missing
    Given I am on the new ambassador page
    When I fill in the ambassador form with:
      | field      | value                     |
      | First Name | Kiran                     |
      | Last Name  | Mehta                     |
      | Email      | no.mobile.amb@drwise.com  |
    And I submit the ambassador form
    Then I should see "Mobile can't be blank"

  Scenario: Reject ambassador when Email is missing
    Given I am on the new ambassador page
    When I fill in the ambassador form with:
      | field      | value      |
      | First Name | Suresh     |
      | Last Name  | Pillai     |
      | Mobile     | 9822200013 |
    And I submit the ambassador form
    Then I should see "Email can't be blank"

  Scenario: Reject ambassador with invalid mobile number
    Given I am on the new ambassador page
    When I fill in the ambassador form with:
      | field      | value                    |
      | First Name | Bad                      |
      | Last Name  | Mobile                   |
      | Mobile     | 1234567890               |
      | Email      | bad.mobile@drwise.com    |
    And I submit the ambassador form
    Then I should see "Mobile must be a valid 10-digit mobile number"

  Scenario: Reject ambassador with invalid email format
    Given I am on the new ambassador page
    When I fill in the ambassador form with:
      | field      | value          |
      | First Name | Invalid        |
      | Last Name  | Email          |
      | Mobile     | 9822200014     |
      | Email      | not-an-email   |
    And I submit the ambassador form
    Then I should see ambassador email format error

  Scenario: Reject ambassador with duplicate mobile
    Given an ambassador exists with mobile "9822200002"
    And I am on the new ambassador page
    When I fill in the ambassador form with:
      | field      | value                 |
      | First Name | Duplicate             |
      | Last Name  | Ambassador            |
      | Mobile     | 9822200002            |
      | Email      | dup.amb@drwise.com    |
    And I submit the ambassador form
    Then I should see ambassador duplicate mobile error

  Scenario: Reject ambassador with duplicate email
    Given an ambassador exists with email "exists@drwise.com" and mobile "9822200015"
    And I am on the new ambassador page
    When I fill in the ambassador form with:
      | field      | value              |
      | First Name | Dup                |
      | Last Name  | Email              |
      | Mobile     | 9822200016         |
      | Email      | exists@drwise.com  |
    And I submit the ambassador form
    Then I should see ambassador duplicate email error

  Scenario: Empty form submission shows all mandatory field errors
    Given I am on the new ambassador page
    When I submit the ambassador form without filling any fields
    Then I should see ambassador validation errors

  # ─── CREATE: ALL FIELDS ────────────────────────────────────────────────────

  Scenario: Create ambassador with all available fields
    Given I am on the new ambassador page
    When I fill in the full ambassador form with:
      | field               | value                         |
      | First Name          | Ramesh                        |
      | Middle Name         | Kumar                         |
      | Last Name           | Verma                         |
      | Mobile              | 9822200020                    |
      | Email               | ramesh.amb.verma@drwise.com   |
      | Birth Date          | 1985-06-15                    |
      | Gender              | Male                          |
      | PAN No              | ABCDE1234F                    |
      | GST No              | 27ABCDE1234F1Z5               |
      | Company Name        | Verma Agencies                |
      | Address             | 45, MG Road, Bengaluru        |
      | Bank Name           | SBI                           |
      | Account Number      | 32145678901234                |
      | IFSC Code           | SBIN0001234                   |
      | Account Holder Name | Ramesh Kumar Verma            |
      | Account Type        | Savings                       |
      | UPI ID              | ramesh@sbi                    |
    And I submit the ambassador form
    Then I should see ambassador created successfully
    And I should see "Ramesh Verma"

  # ─── VIEW: LIST ────────────────────────────────────────────────────────────

  Scenario: View ambassador list shows all ambassadors
    Given an ambassador exists with name "Mohan Das" and mobile "9822200003"
    When I visit the ambassadors list page
    Then I should see "Mohan Das"

  Scenario: Ambassador list shows status badge
    Given an ambassador exists with name "Status Badge" and mobile "9822200030"
    When I visit the ambassadors list page
    Then I should see ambassador status badge on the list

  Scenario: Ambassador list shows total count statistics
    Given an ambassador exists with name "Count Check" and mobile "9822200031"
    When I visit the ambassadors list page
    Then I should see total ambassadors count

  Scenario: Ambassador list shows Deactivate action button
    Given an ambassador exists with name "Action Buttons" and mobile "9822200032"
    When I visit the ambassadors list page
    Then I should see ambassador action buttons

  # ─── VIEW: DETAILS ─────────────────────────────────────────────────────────

  Scenario: View ambassador details shows personal information
    Given an ambassador exists with name "Latha Krishnan" and mobile "9822200004"
    When I click view on ambassador "Latha Krishnan"
    Then I should be on the ambassador show page
    And I should see "Latha Krishnan"
    And I should see "Personal Information"

  Scenario: View ambassador details shows login credentials section
    Given an ambassador exists with name "Login Section" and mobile "9822200040"
    When I click view on ambassador "Login Section"
    Then I should be on the ambassador show page
    And I should see "Login Credentials"

  Scenario: View ambassador details shows bank details section
    Given an ambassador exists with all fields named "Banker" with mobile "9822200041"
    When I click view on ambassador "Banker Testuser"
    Then I should be on the ambassador show page
    And I should see "Bank Details"
    And I should see "SBI"

  Scenario: View ambassador details shows assigned affiliates section
    Given an ambassador exists with name "Affiliate Owner" and mobile "9822200042"
    When I click view on ambassador "Affiliate Owner"
    Then I should be on the ambassador show page
    And I should see "Assigned Affiliates"

  # ─── EDIT ──────────────────────────────────────────────────────────────────

  Scenario: Edit ambassador first name
    Given an ambassador exists with name "Girish Kumar" and mobile "9822200005"
    When I click edit on ambassador "Girish Kumar"
    And I update the ambassador first name to "Girish Updated"
    And I submit the ambassador form
    Then I should see ambassador updated successfully
    And I should see "Girish Updated"

  Scenario: Edit ambassador last name
    Given an ambassador exists with name "Priya Reddy" and mobile "9822200050"
    When I click edit on ambassador "Priya Reddy"
    And I update the ambassador last name to "Malhotra"
    And I submit the ambassador form
    Then I should see ambassador updated successfully
    And I should see "Malhotra"

  Scenario: Edit ambassador email
    Given an ambassador exists with name "Email Edit Amb" and mobile "9822200051"
    When I click edit on ambassador "Email Edit Amb"
    And I update the ambassador email to "updated.amb@drwise.com"
    And I submit the ambassador form
    Then I should see ambassador updated successfully

  Scenario: Edit ambassador mobile number
    Given an ambassador exists with name "Mobile Edit Amb" and mobile "9822200052"
    When I click edit on ambassador "Mobile Edit Amb"
    And I update the ambassador mobile to "9822200088"
    And I submit the ambassador form
    Then I should see ambassador updated successfully

  Scenario: Edit ambassador bank details
    Given an ambassador exists with name "Bank Edit Amb" and mobile "9822200053"
    When I click edit on ambassador "Bank Edit Amb"
    And I update the ambassador bank details with:
      | field               | value          |
      | Bank Name           | HDFC Bank      |
      | Account Number      | 50100123456789 |
      | IFSC Code           | HDFC0001234    |
      | Account Holder Name | Bank Edit Amb  |
      | Account Type        | Current        |
      | UPI ID              | bankedit@hdfc  |
    And I submit the ambassador form
    Then I should see ambassador updated successfully

  Scenario: Edit ambassador personal details
    Given an ambassador exists with name "Personal Edit" and mobile "9822200054"
    When I click edit on ambassador "Personal Edit"
    And I update the ambassador personal details with:
      | field        | value             |
      | Middle Name  | Updated           |
      | Gender       | Female            |
      | PAN No       | ZYXWV9876A        |
      | Company Name | Updated Company   |
      | Address      | 99 New Street     |
    And I submit the ambassador form
    Then I should see ambassador updated successfully

  Scenario: Edit ambassador - clearing mandatory first name shows error
    Given an ambassador exists with name "Clear Test Amb" and mobile "9822200055"
    When I click edit on ambassador "Clear Test Amb"
    And I clear the ambassador first name field
    And I submit the ambassador form
    Then I should see "First name can't be blank"

  # ─── DEACTIVATE / ACTIVATE ─────────────────────────────────────────────────

  Scenario: Deactivate an active ambassador
    Given an ambassador exists with name "Deactivate Me" and mobile "9822200060"
    When I visit the ambassadors list page
    And I deactivate ambassador "Deactivate Me"
    Then I should see ambassador deactivated successfully

  Scenario: Activate a deactivated ambassador
    Given a deactivated ambassador exists with name "Activate Me" and mobile "9822200061"
    When I visit the ambassadors list page
    And I activate ambassador "Activate Me"
    Then I should see ambassador activated successfully

  Scenario: Deactivated ambassador shows deactivated label in list
    Given a deactivated ambassador exists with name "Show Deactivated" and mobile "9822200062"
    When I visit the ambassadors list page
    Then I should see "Deactivated" for ambassador "Show Deactivated"

  # ─── DELETE ────────────────────────────────────────────────────────────────

  Scenario: Delete an ambassador
    Given an ambassador exists with name "Delete Ambassador" and mobile "9822200099"
    When I visit the ambassadors list page
    And I delete ambassador "Delete Ambassador"
    Then I should not see "Delete Ambassador" on the ambassadors page

  Scenario: Delete ambassador shows success message
    Given an ambassador exists with name "Delete Confirm Amb" and mobile "9822200098"
    When I visit the ambassadors list page
    And I delete ambassador "Delete Confirm Amb"
    Then I should see ambassador deleted successfully
