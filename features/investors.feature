@javascript
Feature: Investor Management
  As an admin
  I want to manage investors
  So that I can create, view, edit, and delete investor records

  Background:
    Given I am logged in as admin
    And test prerequisites exist

  # ─── CREATE: COMPULSORY FIELDS ─────────────────────────────────────────────

  Scenario: Create investor with only mandatory fields
    Given I am on the new investor page
    When I fill in the investor form with:
      | field      | value                    |
      | First Name | Anand                    |
      | Last Name  | Joshi                    |
      | Mobile     | 9833300001               |
      | Email      | anand.joshi@invest.com   |
    And I submit the investor form
    Then I should see investor created successfully
    And I should see "Anand Joshi"

  Scenario: Reject investor when First Name is missing
    Given I am on the new investor page
    When I fill in the investor form with:
      | field      | value                      |
      | Last Name  | Sharma                     |
      | Mobile     | 9833300011                 |
      | Email      | no.firstname@invest.com    |
    And I submit the investor form
    Then I should see "First name can't be blank"

  Scenario: Reject investor when Last Name is missing
    Given I am on the new investor page
    When I fill in the investor form with:
      | field      | value                     |
      | First Name | Priya                     |
      | Mobile     | 9833300012                |
      | Email      | no.lastname@invest.com    |
    And I submit the investor form
    Then I should see "Last name can't be blank"

  Scenario: Reject investor when Mobile is missing
    Given I am on the new investor page
    When I fill in the investor form with:
      | field      | value                    |
      | First Name | Kiran                    |
      | Last Name  | Mehta                    |
      | Email      | no.mobile@invest.com     |
    And I submit the investor form
    Then I should see "Mobile can't be blank"

  Scenario: Reject investor when Email is missing
    Given I am on the new investor page
    When I fill in the investor form with:
      | field      | value          |
      | First Name | Suresh         |
      | Last Name  | Pillai         |
      | Mobile     | 9833300013     |
    And I submit the investor form
    Then I should see "Email can't be blank"

  Scenario: Reject investor with invalid mobile number
    Given I am on the new investor page
    When I fill in the investor form with:
      | field      | value              |
      | First Name | Bad                |
      | Last Name  | Mobile             |
      | Mobile     | 1234567890         |
      | Email      | bad.mob@invest.com |
    And I submit the investor form
    Then I should see "Mobile must be a valid 10-digit mobile number"

  Scenario: Reject investor with invalid email format
    Given I am on the new investor page
    When I fill in the investor form with:
      | field      | value          |
      | First Name | Invalid        |
      | Last Name  | Email          |
      | Mobile     | 9833300014     |
      | Email      | not-an-email   |
    And I submit the investor form
    Then I should see investor email format error

  Scenario: Reject investor with duplicate email
    Given an investor exists with email "existing@invest.com" and mobile "9833300002"
    And I am on the new investor page
    When I fill in the investor form with:
      | field      | value               |
      | First Name | Duplicate           |
      | Last Name  | Email               |
      | Mobile     | 9833300003          |
      | Email      | existing@invest.com |
    And I submit the investor form
    Then I should see "Email has already been taken"

  Scenario: Reject investor with duplicate mobile
    Given an investor exists with email "unique@invest.com" and mobile "9833300015"
    And I am on the new investor page
    When I fill in the investor form with:
      | field      | value               |
      | First Name | Duplicate           |
      | Last Name  | Mobile              |
      | Mobile     | 9833300015          |
      | Email      | dup.mob@invest.com  |
    And I submit the investor form
    Then I should see "Mobile has already been taken"

  Scenario: Empty form submission shows all mandatory field errors
    Given I am on the new investor page
    When I submit the investor form without filling any fields
    Then I should see investor validation errors

  # ─── CREATE: ALL FIELDS ────────────────────────────────────────────────────

  Scenario: Create investor with all available fields
    Given I am on the new investor page
    When I fill in the full investor form with:
      | field                  | value                         |
      | First Name             | Ramesh                        |
      | Middle Name            | Kumar                         |
      | Last Name              | Verma                         |
      | Mobile                 | 9833300020                    |
      | Email                  | ramesh.verma@invest.com       |
      | Birth Date             | 1985-06-15                    |
      | Gender                 | Male                          |
      | PAN No                 | ABCDE1234F                    |
      | GST No                 | 27ABCDE1234F1Z5               |
      | Company Name           | Verma Enterprises             |
      | Address                | 123, MG Road, Mumbai          |
      | Bank Name              | HDFC Bank                     |
      | Account Number         | 50100123456789                |
      | IFSC Code              | HDFC0001234                   |
      | Account Holder Name    | Ramesh Kumar Verma            |
      | Account Type           | Savings                       |
      | UPI ID                 | ramesh@hdfc                   |
      | No of Shares           | 100                           |
      | Invested Amount        | 500000                        |
      | Investment Percentage  | 10                            |
    And I submit the investor form
    Then I should see investor created successfully
    And I should see "Ramesh Verma"

  # ─── VIEW: LIST ────────────────────────────────────────────────────────────

  Scenario: View investor list shows all investors
    Given an investor exists with name "Seema Gupta" and mobile "9833300004"
    When I visit the investors list page
    Then I should see "Seema Gupta"

  Scenario: Investor list shows status badge
    Given an investor exists with name "Active Investor" and mobile "9833300030"
    When I visit the investors list page
    Then I should see investor status on the list

  Scenario: Investor list shows total investor count
    Given an investor exists with name "Count Check" and mobile "9833300031"
    When I visit the investors list page
    Then I should see total investors count

  # ─── VIEW: DETAILS ─────────────────────────────────────────────────────────

  Scenario: View investor details shows personal information
    Given an investor exists with name "Rohan Tiwari" and mobile "9833300005"
    When I click view on investor "Rohan Tiwari"
    Then I should be on the investor show page
    And I should see "Rohan Tiwari"
    And I should see "Personal Information"

  Scenario: View investor details shows login credentials section
    Given an investor exists with name "Login Check" and mobile "9833300032"
    When I click view on investor "Login Check"
    Then I should be on the investor show page
    And I should see "Login Credentials"

  Scenario: View investor details shows account information
    Given an investor exists with name "Account Check" and mobile "9833300033"
    When I click view on investor "Account Check"
    Then I should be on the investor show page
    And I should see "Account Information"
    And I should see "Investor ID"

  Scenario: View investor with bank details shows banking section
    Given an investor exists with all fields named "Banker" with mobile "9833300034"
    When I click view on investor "Banker Testuser"
    Then I should be on the investor show page
    And I should see "Banking Information"
    And I should see "HDFC Bank"

  Scenario: View investor with investment details shows investment section
    Given an investor exists with all fields named "Investor" with mobile "9833300035"
    When I click view on investor "Investor Testuser"
    Then I should be on the investor show page
    And I should see "Investment Details"
    And I should see "No. of Shares"

  # ─── VIEW: SUMMARY ─────────────────────────────────────────────────────────

  Scenario: View investor summary page
    Given an investor exists with name "Summary Check" and mobile "9833300040"
    When I click view on investor "Summary Check"
    And I navigate to the investor summary
    Then I should be on the investor summary page
    And I should see "Summary Check"

  Scenario: Investor summary shows commission rows section
    Given an investor exists with name "Commission Check" and mobile "9833300041"
    When I click view on investor "Commission Check"
    And I navigate to the investor summary
    Then I should be on the investor summary page
    And I should see investor commission section

  Scenario: Investor summary shows ambassador network section
    Given an investor exists with name "Network Check" and mobile "9833300042"
    When I click view on investor "Network Check"
    And I navigate to the investor summary
    Then I should be on the investor summary page
    And I should see ambassador network section

  # ─── EDIT ──────────────────────────────────────────────────────────────────

  Scenario: Edit investor first name
    Given an investor exists with name "Neeraj Sharma" and mobile "9833300006"
    When I click edit on investor "Neeraj Sharma"
    And I update the investor first name to "Neeraj Updated"
    And I submit the investor form
    Then I should see investor updated successfully
    And I should see "Neeraj Updated"

  Scenario: Edit investor last name
    Given an investor exists with name "Priya Kapoor" and mobile "9833300050"
    When I click edit on investor "Priya Kapoor"
    And I update the investor last name to "Malhotra"
    And I submit the investor form
    Then I should see investor updated successfully
    And I should see "Malhotra"

  Scenario: Edit investor email
    Given an investor exists with name "Email Edit" and mobile "9833300051"
    When I click edit on investor "Email Edit"
    And I update the investor email to "updated.email@invest.com"
    And I submit the investor form
    Then I should see investor updated successfully

  Scenario: Edit investor mobile number
    Given an investor exists with name "Mobile Edit" and mobile "9833300052"
    When I click edit on investor "Mobile Edit"
    And I update the investor mobile to "9833300099"
    And I submit the investor form
    Then I should see investor updated successfully

  Scenario: Edit investor bank details
    Given an investor exists with name "Bank Edit" and mobile "9833300053"
    When I click edit on investor "Bank Edit"
    And I update the investor bank details with:
      | field               | value          |
      | Bank Name           | ICICI Bank     |
      | Account Number      | 60100987654321 |
      | IFSC Code           | ICIC0001234    |
      | Account Holder Name | Bank Edit      |
      | Account Type        | Current        |
    And I submit the investor form
    Then I should see investor updated successfully

  Scenario: Edit investor investment details
    Given an investor exists with name "Invest Edit" and mobile "9833300054"
    When I click edit on investor "Invest Edit"
    And I update the investor investment details with:
      | field                 | value   |
      | No of Shares          | 200     |
      | Invested Amount       | 1000000 |
      | Investment Percentage | 20      |
    And I submit the investor form
    Then I should see investor updated successfully

  Scenario: Edit investor - clearing mandatory first name shows error
    Given an investor exists with name "Clear Test" and mobile "9833300055"
    When I click edit on investor "Clear Test"
    And I clear the investor first name field
    And I submit the investor form
    Then I should see "First name can't be blank"

  Scenario: Toggle investor status from active to inactive
    Given an investor exists with name "Status Toggle" and mobile "9833300060"
    When I visit the investors list page
    And I toggle the status of investor "Status Toggle"
    Then I should see investor status changed

  # ─── DELETE ────────────────────────────────────────────────────────────────

  Scenario: Delete an investor
    Given an investor exists with name "Delete Investor" and mobile "9833300099"
    When I visit the investors list page
    And I delete investor "Delete Investor"
    Then I should not see "Delete Investor" on the investors page

  Scenario: Delete investor shows success message
    Given an investor exists with name "Delete Message" and mobile "9833300098"
    When I visit the investors list page
    And I delete investor "Delete Message"
    Then I should see investor deleted successfully
