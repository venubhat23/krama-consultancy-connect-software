@javascript
Feature: Affiliate Management
  As an admin
  I want to manage affiliates (sub-agents)
  So that I can create, view, edit, deactivate, and delete affiliate records

  Background:
    Given I am logged in as admin
    And test prerequisites exist

  # ─── SIDEBAR NAVIGATION ────────────────────────────────────────────────────

  Scenario: Affiliates link in sidebar navigates to affiliates list
    When I click sidebar link "Affiliates"
    Then the URL should include "/admin/sub_agents"
    And the page should load successfully

  Scenario: Sidebar Affiliates link shows correct page heading
    When I click sidebar link "Affiliates"
    Then I should see affiliate list heading

  # ─── CREATE: COMPULSORY FIELDS ─────────────────────────────────────────────

  Scenario: Create affiliate with only mandatory fields
    Given I am on the new affiliate page
    When I fill in the affiliate form with:
      | field      | value                  |
      | First Name | Ramesh                 |
      | Last Name  | Patil                  |
      | Mobile     | 9811100001             |
      | Email      | ramesh.patil@test.com  |
      | Password   | Password@123           |
    And I submit the affiliate form
    Then I should see affiliate created successfully
    And I should see "Ramesh Patil"

  Scenario: Reject affiliate when First Name is missing
    Given I am on the new affiliate page
    When I fill in the affiliate form with:
      | field      | value                      |
      | Last Name  | Sharma                     |
      | Mobile     | 9811100011                 |
      | Email      | no.firstname.aff@test.com  |
      | Password   | Password@123               |
    And I submit the affiliate form
    Then I should see "First name can't be blank"

  Scenario: Reject affiliate when Last Name is missing
    Given I am on the new affiliate page
    When I fill in the affiliate form with:
      | field      | value                     |
      | First Name | Priya                     |
      | Mobile     | 9811100012                |
      | Email      | no.lastname.aff@test.com  |
      | Password   | Password@123              |
    And I submit the affiliate form
    Then I should see "Last name can't be blank"

  Scenario: Reject affiliate when Mobile is missing
    Given I am on the new affiliate page
    When I fill in the affiliate form with:
      | field      | value                    |
      | First Name | Kiran                    |
      | Last Name  | Mehta                    |
      | Email      | no.mobile.aff@test.com   |
      | Password   | Password@123             |
    And I submit the affiliate form
    Then I should see "Mobile can't be blank"

  Scenario: Reject affiliate when Email is missing
    Given I am on the new affiliate page
    When I fill in the affiliate form with:
      | field      | value      |
      | First Name | Suresh     |
      | Last Name  | Pillai     |
      | Mobile     | 9811100013 |
      | Password   | Password@123 |
    And I submit the affiliate form
    Then I should see "Email can't be blank"

  Scenario: Reject affiliate with invalid mobile number
    Given I am on the new affiliate page
    When I fill in the affiliate form with:
      | field      | value                   |
      | First Name | Bad                     |
      | Last Name  | Mobile                  |
      | Mobile     | 1234567890              |
      | Email      | bad.mobile@test.com     |
      | Password   | Password@123            |
    And I submit the affiliate form
    Then I should see "Mobile must be a valid 10-digit"

  Scenario: Reject affiliate with invalid email format
    Given I am on the new affiliate page
    When I fill in the affiliate form with:
      | field      | value          |
      | First Name | Invalid        |
      | Last Name  | Email          |
      | Mobile     | 9811100014     |
      | Email      | not-an-email   |
      | Password   | Password@123   |
    And I submit the affiliate form
    Then I should see affiliate email format error

  Scenario: Reject affiliate with duplicate mobile
    Given an affiliate exists with mobile "9811100002"
    And I am on the new affiliate page
    When I fill in the affiliate form with:
      | field      | value                 |
      | First Name | Duplicate             |
      | Last Name  | Mobile                |
      | Mobile     | 9811100002            |
      | Email      | dup.mobile@test.com   |
      | Password   | Password@123          |
    And I submit the affiliate form
    Then I should see "already exists"

  Scenario: Reject affiliate with duplicate email
    Given an affiliate exists with email "exists@test.com" and mobile "9811100015"
    And I am on the new affiliate page
    When I fill in the affiliate form with:
      | field      | value              |
      | First Name | Dup                |
      | Last Name  | Email              |
      | Mobile     | 9811100016         |
      | Email      | exists@test.com    |
      | Password   | Password@123       |
    And I submit the affiliate form
    Then I should see "already exists"

  Scenario: Empty form submission shows all mandatory field errors
    Given I am on the new affiliate page
    When I submit the affiliate form without filling any fields
    Then I should see affiliate validation errors

  # ─── CREATE: ALL FIELDS ────────────────────────────────────────────────────

  Scenario: Create affiliate with all available fields
    Given I am on the new affiliate page
    When I fill in the full affiliate form with:
      | field               | value                         |
      | First Name          | Sanjay                        |
      | Middle Name         | Mohan                         |
      | Last Name           | Kulkarni                      |
      | Mobile              | 9811100020                    |
      | Email               | sanjay.kulkarni@test.com      |
      | Password            | Secure@456                    |
      | Birth Date          | 1990-03-22                    |
      | Gender              | Male                          |
      | PAN No              | FGHIJ5678K                    |
      | GST No              | 29FGHIJ5678K1Z3               |
      | Company Name        | Kulkarni Associates           |
      | Address             | 10, Park Street, Pune         |
      | Bank Name           | Axis Bank                     |
      | Account Number      | 91801234567890                |
      | IFSC Code           | UTIB0001234                   |
      | Account Holder Name | Sanjay Mohan Kulkarni         |
      | Account Type        | Savings                       |
      | UPI ID              | sanjay@axis                   |
    And I submit the affiliate form
    Then I should see affiliate created successfully
    And I should see "Sanjay Kulkarni"

  # ─── VIEW: LIST ────────────────────────────────────────────────────────────

  Scenario: View affiliate list shows all affiliates
    Given an affiliate exists with name "Sonal Shah" and mobile "9811100003"
    When I visit the affiliates list page
    Then I should see "Sonal Shah"

  Scenario: Affiliate list shows status badge
    Given an affiliate exists with name "Status Badge Aff" and mobile "9811100030"
    When I visit the affiliates list page
    Then I should see affiliate status badge on the list

  Scenario: Affiliate list shows total count statistics
    Given an affiliate exists with name "Count Check Aff" and mobile "9811100031"
    When I visit the affiliates list page
    Then I should see total affiliates count

  Scenario: Affiliate list shows Deactivate action button
    Given an affiliate exists with name "Action Btn Aff" and mobile "9811100032"
    When I visit the affiliates list page
    Then I should see affiliate action buttons

  # ─── VIEW: DETAILS ─────────────────────────────────────────────────────────

  Scenario: View affiliate details shows personal information
    Given an affiliate exists with name "Vijay Naik" and mobile "9811100004"
    When I click view on affiliate "Vijay Naik"
    Then I should be on the affiliate show page
    And I should see "Vijay Naik"
    And I should see "Personal Details"

  Scenario: View affiliate details shows login credentials section
    Given an affiliate exists with name "Login Aff" and mobile "9811100040"
    When I click view on affiliate "Login Aff"
    Then I should be on the affiliate show page
    And I should see "Login Credentials"

  Scenario: View affiliate details shows bank details section
    Given an affiliate exists with all fields named "BankAff" with mobile "9811100041"
    When I click view on affiliate "BankAff Testuser"
    Then I should be on the affiliate show page
    And I should see "Bank Details"

  Scenario: View affiliate details shows ambassador assignment section
    Given an affiliate exists with name "Assigned Aff" and mobile "9811100042"
    When I click view on affiliate "Assigned Aff"
    Then I should be on the affiliate show page
    And I should see "Ambassador Assignment"

  # ─── EDIT ──────────────────────────────────────────────────────────────────

  Scenario: Edit affiliate first name
    Given an affiliate exists with name "Suresh Reddy" and mobile "9811100005"
    When I click edit on affiliate "Suresh Reddy"
    And I update the affiliate first name to "Suresh Updated"
    And I submit the affiliate form
    Then I should see affiliate updated successfully
    And I should see "Suresh Updated"

  Scenario: Edit affiliate last name
    Given an affiliate exists with name "Priya Joshi" and mobile "9811100050"
    When I click edit on affiliate "Priya Joshi"
    And I update the affiliate last name to "Nair"
    And I submit the affiliate form
    Then I should see affiliate updated successfully
    And I should see "Nair"

  Scenario: Edit affiliate email
    Given an affiliate exists with name "Email Edit Aff" and mobile "9811100051"
    When I click edit on affiliate "Email Edit Aff"
    And I update the affiliate email to "updated.aff@test.com"
    And I submit the affiliate form
    Then I should see affiliate updated successfully

  Scenario: Edit affiliate mobile number
    Given an affiliate exists with name "Mobile Edit Aff" and mobile "9811100052"
    When I click edit on affiliate "Mobile Edit Aff"
    And I update the affiliate mobile to "9811100088"
    And I submit the affiliate form
    Then I should see affiliate updated successfully

  Scenario: Edit affiliate bank details
    Given an affiliate exists with name "Bank Edit Aff" and mobile "9811100053"
    When I click edit on affiliate "Bank Edit Aff"
    And I update the affiliate bank details with:
      | field               | value          |
      | Bank Name           | ICICI Bank     |
      | Account Number      | 60100987654321 |
      | IFSC Code           | ICIC0001234    |
      | Account Holder Name | Bank Edit Aff  |
      | Account Type        | Current        |
      | UPI ID              | bankaff@icici  |
    And I submit the affiliate form
    Then I should see affiliate updated successfully

  Scenario: Edit affiliate personal details
    Given an affiliate exists with name "Personal Aff" and mobile "9811100054"
    When I click edit on affiliate "Personal Aff"
    And I update the affiliate personal details with:
      | field        | value            |
      | Middle Name  | Updated          |
      | Gender       | Female           |
      | PAN No       | LMNOP1234Q       |
      | Company Name | Updated Firm     |
      | Address      | 77 Updated Road  |
    And I submit the affiliate form
    Then I should see affiliate updated successfully

  Scenario: Edit affiliate - clearing mandatory first name shows error
    Given an affiliate exists with name "Clear Test Aff" and mobile "9811100055"
    When I click edit on affiliate "Clear Test Aff"
    And I clear the affiliate first name field
    And I submit the affiliate form
    Then I should see "First name can't be blank"

  # ─── DEACTIVATE / ACTIVATE ─────────────────────────────────────────────────

  Scenario: Deactivate an active affiliate
    Given an affiliate exists with name "Deactivate Aff" and mobile "9811100060"
    When I visit the affiliates list page
    And I deactivate affiliate "Deactivate Aff"
    Then I should see affiliate deactivated successfully

  Scenario: Activate a deactivated affiliate
    Given a deactivated affiliate exists with name "Activate Aff" and mobile "9811100061"
    When I visit the affiliates list page
    And I activate affiliate "Activate Aff"
    Then I should see affiliate activated successfully

  Scenario: Deactivated affiliate shows deactivated label in list
    Given a deactivated affiliate exists with name "Show Deactivated Aff" and mobile "9811100062"
    When I visit the affiliates list page
    Then I should see "Deactivated" for affiliate "Show Deactivated Aff"

  # ─── DELETE ────────────────────────────────────────────────────────────────

  Scenario: Delete an affiliate
    Given an affiliate exists with name "Delete Affiliate" and mobile "9811100099"
    When I visit the affiliates list page
    And I delete affiliate "Delete Affiliate"
    Then I should not see "Delete Affiliate" on the affiliates page

  Scenario: Delete affiliate shows success message
    Given an affiliate exists with name "Delete Confirm Aff" and mobile "9811100098"
    When I visit the affiliates list page
    And I delete affiliate "Delete Confirm Aff"
    Then I should see affiliate deleted successfully
