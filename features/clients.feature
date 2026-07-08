@javascript
Feature: Client Management
  As an admin
  I want to manage clients (customers)
  So that I can create, view, edit, and delete client records

  Background:
    Given I am logged in as admin
    And test prerequisites exist

  # ─── SIDEBAR NAVIGATION ──────────────────────────────────────────────────────

  Scenario: Clients link in sidebar navigates to clients list
    When I click sidebar link "Clients"
    Then the URL should include "/admin/customers"

  # ═══════════════════════════════════════════════════════════════════════════
  # CREATE: INDIVIDUAL CUSTOMER
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Create individual client with compulsory fields only
    Given I am on the new client page
    When I select client type "Individual"
    And I fill in the individual client form with:
      | field         | value        |
      | First Name    | Rahul        |
      | Last Name     | Verma        |
      | Mobile        | 9812345670   |
      | Date of Birth | 1990-05-15   |
      | Nominee Name  | Sunita Verma |
      | Nominee DOB   | 1992-08-20   |
    And I select nominee relation "Spouse"
    And I submit the client form
    Then I should see client created successfully
    And I should see "Rahul Verma"

  Scenario: Create individual client with all fields including bank details
    Given I am on the new client page
    When I select client type "Individual"
    And I fill in the individual client form with:
      | field         | value                  |
      | First Name    | Deepak                 |
      | Last Name     | Sharma                 |
      | Mobile        | 9812345671             |
      | Email         | deepak.sharma@test.com |
      | Date of Birth | 1985-07-20             |
      | Nominee Name  | Meena Sharma           |
      | Nominee DOB   | 1987-03-15             |
    And I select nominee relation "Spouse"
    And I fill in the bank details with:
      | field          | value       |
      | Bank Name      | HDFC Bank   |
      | Account Number | 1234567890  |
      | IFSC Code      | HDFC0001234 |
    And I submit the client form
    Then I should see client created successfully
    And I should see "Deepak Sharma"

  Scenario: Validation error when first name is missing for individual
    Given I am on the new client page
    When I select client type "Individual"
    And I fill in the individual client form with:
      | field         | value        |
      | Last Name     | Verma        |
      | Mobile        | 9812345672   |
      | Date of Birth | 1990-05-15   |
      | Nominee Name  | Sunita Verma |
      | Nominee DOB   | 1992-08-20   |
    And I select nominee relation "Spouse"
    And I submit the client form
    Then I should see individual client missing field error for "First name"

  Scenario: Validation error when last name is missing for individual
    Given I am on the new client page
    When I select client type "Individual"
    And I fill in the individual client form with:
      | field         | value        |
      | First Name    | Rahul        |
      | Mobile        | 9812345673   |
      | Date of Birth | 1990-05-15   |
      | Nominee Name  | Sunita Verma |
      | Nominee DOB   | 1992-08-20   |
    And I select nominee relation "Spouse"
    And I submit the client form
    Then I should see individual client missing field error for "Last name"

  Scenario: Validation error when mobile is missing for individual
    Given I am on the new client page
    When I select client type "Individual"
    And I fill in the individual client form with:
      | field         | value        |
      | First Name    | Rahul        |
      | Last Name     | Verma        |
      | Date of Birth | 1990-05-15   |
      | Nominee Name  | Sunita Verma |
      | Nominee DOB   | 1992-08-20   |
    And I select nominee relation "Spouse"
    And I submit the client form
    Then I should see individual client missing field error for "Mobile"

  Scenario: Validation error when birth date is missing for individual
    Given I am on the new client page
    When I select client type "Individual"
    And I fill in the individual client form with:
      | field        | value        |
      | First Name   | Rahul        |
      | Last Name    | Verma        |
      | Mobile       | 9812345674   |
      | Nominee Name | Sunita Verma |
      | Nominee DOB  | 1992-08-20   |
    And I select nominee relation "Spouse"
    And I submit the client form
    Then I should see individual client missing field error for "Birth date"

  Scenario: Validation error when nominee name is missing for individual
    Given I am on the new client page
    When I select client type "Individual"
    And I fill in the individual client form with:
      | field         | value      |
      | First Name    | Rahul      |
      | Last Name     | Verma      |
      | Mobile        | 9812345675 |
      | Date of Birth | 1990-05-15 |
      | Nominee DOB   | 1992-08-20 |
    And I select nominee relation "Spouse"
    And I submit the client form
    Then I should see individual client missing field error for "Nominee name"

  Scenario: Invalid mobile number for individual customer
    Given I am on the new client page
    When I select client type "Individual"
    And I fill in the individual client form with:
      | field         | value        |
      | First Name    | Rahul        |
      | Last Name     | Verma        |
      | Mobile        | 1234567890   |
      | Date of Birth | 1990-05-15   |
      | Nominee Name  | Sunita Verma |
      | Nominee DOB   | 1992-08-20   |
    And I select nominee relation "Spouse"
    And I submit the client form
    Then I should see client mobile format error

  Scenario: Duplicate mobile number for individual customer
    Given an individual client exists with mobile "9812345679"
    And I am on the new client page
    When I select client type "Individual"
    And I fill in the individual client form with:
      | field         | value        |
      | First Name    | Duplicate    |
      | Last Name     | Mobile       |
      | Mobile        | 9812345679   |
      | Date of Birth | 1990-05-15   |
      | Nominee Name  | Sunita Verma |
      | Nominee DOB   | 1992-08-20   |
    And I select nominee relation "Spouse"
    And I submit the client form
    Then I should see client duplicate mobile error

  Scenario: Empty individual form shows validation errors
    Given I am on the new client page
    When I select client type "Individual"
    And I submit the client form without filling any fields
    Then I should see client validation errors for individual

  # ═══════════════════════════════════════════════════════════════════════════
  # CREATE: CORPORATE CUSTOMER
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Create corporate client with compulsory fields only
    Given I am on the new client page
    When I select client type "Corporate"
    And I fill in the corporate client form with:
      | field        | value              |
      | Company Name | Acme Insurance Ltd |
      | Mobile       | 9900001111         |
      | Email        | acme@example.com   |
      | GST No       | 27AAPFU0939F1ZV    |
    And I submit the client form
    Then I should see client created successfully
    And I should see "Acme Insurance Ltd"

  Scenario: Create corporate client with optional fields
    Given I am on the new client page
    When I select client type "Corporate"
    And I fill in the corporate client form with:
      | field        | value                  |
      | Company Name | GlobalTech Solutions   |
      | Mobile       | 9900002222             |
      | Email        | globaltech@example.com |
      | GST No       | 29AABCT1332L1ZX        |
    And I submit the client form
    Then I should see client created successfully
    And I should see "GlobalTech Solutions"

  Scenario: Validation error when company name is missing for corporate
    Given I am on the new client page
    When I select client type "Corporate"
    And I fill in the corporate client form with:
      | field  | value              |
      | Mobile | 9900003333         |
      | Email  | noname@example.com |
      | GST No | 27AAPFU0939F1ZV    |
    And I submit the client form
    Then I should see corporate client missing field error for "Company name"

  Scenario: Validation error when mobile is missing for corporate
    Given I am on the new client page
    When I select client type "Corporate"
    And I fill in the corporate client form with:
      | field        | value                |
      | Company Name | NoMobile Corp        |
      | Email        | nomobile@example.com |
      | GST No       | 27AAPFU0939F1ZV      |
    And I submit the client form
    Then I should see corporate client missing field error for "Mobile"

  Scenario: Validation error when email is missing for corporate
    Given I am on the new client page
    When I select client type "Corporate"
    And I fill in the corporate client form with:
      | field        | value           |
      | Company Name | NoEmail Corp    |
      | Mobile       | 9900004444      |
      | GST No       | 27AAPFU0939F1ZV |
    And I submit the client form
    Then I should see corporate client missing field error for "Email"

  Scenario: Validation error when GST number is missing for corporate
    Given I am on the new client page
    When I select client type "Corporate"
    And I fill in the corporate client form with:
      | field        | value             |
      | Company Name | NoGST Corp        |
      | Mobile       | 9900005555        |
      | Email        | nogst@example.com |
    And I submit the client form
    Then I should see corporate client missing field error for "Gst no"

  Scenario: Empty corporate form shows validation errors
    Given I am on the new client page
    When I select client type "Corporate"
    And I submit the client form without filling any fields
    Then I should see client validation errors for corporate

  # ═══════════════════════════════════════════════════════════════════════════
  # VIEW: LISTING PAGE
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Client list shows individual client record
    Given a client exists with name "Priya Sharma" and mobile "9700001234"
    When I visit the clients list page
    Then I should see "Priya Sharma"

  Scenario: Client list shows both individual and corporate clients
    Given a client exists with name "Kiran Patel" and mobile "9700002345"
    And a corporate client exists with company "Kiran Corp" and mobile "9700002346"
    When I visit the clients list page
    Then I should see "Kiran Patel"
    And I should see "Kiran Corp"

  Scenario: Client list displays total count statistic
    Given a client exists with name "Count Test" and mobile "9700003456"
    When I visit the clients list page
    Then I should see client list total count

  Scenario: Client list shows status badge for each customer
    Given a client exists with name "Status Badge" and mobile "9700004567"
    When I visit the clients list page
    Then I should see client status badge

  Scenario: Client list shows view and edit action buttons
    Given a client exists with name "Actions Test" and mobile "9700005678"
    When I visit the clients list page
    Then I should see client list action buttons

  Scenario: Filter client list by individual type shows only individual clients
    Given a client exists with name "IndFilter Client" and mobile "9700006789"
    When I visit the clients list page with type filter "individual"
    Then I should see "IndFilter Client"

  Scenario: Filter client list by corporate type shows only corporate clients
    Given a corporate client exists with company "CorpFilter Co" and mobile "9700007890"
    When I visit the clients list page with type filter "corporate"
    Then I should see "CorpFilter Co"

  # ═══════════════════════════════════════════════════════════════════════════
  # VIEW: INDIVIDUAL CLIENT DETAILS (SHOW PAGE)
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: View individual client details page is accessible
    Given a client exists with name "Kiran View" and mobile "9700008901"
    When I click view on client "Kiran View"
    Then I should be on the client show page
    And I should see "Kiran View"

  Scenario: Individual client show page has Basic Information section
    Given a client exists with name "BasicInfo Test" and mobile "9700009012"
    When I click view on client "BasicInfo Test"
    Then I should see "Basic Information"

  Scenario: Individual client show page has Professional Information section
    Given a client exists with name "ProfInfo Test" and mobile "9700009123"
    When I click view on client "ProfInfo Test"
    Then I should see "Professional Information"

  Scenario: Individual client show page has Address Information section
    Given a client exists with name "AddrInfo Test" and mobile "9700009234"
    When I click view on client "AddrInfo Test"
    Then I should see "Address Information"

  Scenario: Individual client show page has Nominee Information section
    Given a client exists with name "NomInfo Test" and mobile "9700009345"
    When I click view on client "NomInfo Test"
    Then I should see "Nominee Information"

  Scenario: Individual client show page displays the customer name in header
    Given an individual client exists with all fields named "FullInfo" with mobile "9700009456"
    When I click view on client "FullInfo Testuser"
    Then I should see "FullInfo Testuser"
    And I should see "ACTIVE"

  # ═══════════════════════════════════════════════════════════════════════════
  # VIEW: CORPORATE CLIENT DETAILS (SHOW PAGE)
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: View corporate client show page is accessible
    Given a corporate client exists with company "ViewCorp Ltd" and mobile "9700009567"
    When I click view on client "ViewCorp Ltd"
    Then I should be on the client show page
    And I should see "ViewCorp Ltd"

  Scenario: Corporate client show page has Basic Information section
    Given a corporate client exists with company "CorpSection" and mobile "9700009678"
    When I click view on client "CorpSection"
    Then I should see "Basic Information"

  # ═══════════════════════════════════════════════════════════════════════════
  # EDIT
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Edit individual client first name
    Given a client exists with name "Anil Mehta" and mobile "9800001111"
    When I click edit on client "Anil Mehta"
    And I update the client first name to "Anil Updated"
    And I submit the client form
    Then I should see client updated successfully
    And I should see "Anil Updated"

  Scenario: Edit individual client last name
    Given a client exists with name "Raj Singh" and mobile "9800002222"
    When I click edit on client "Raj Singh"
    And I update the client last name to "Singh Updated"
    And I submit the client form
    Then I should see client updated successfully
    And I should see "Singh Updated"

  Scenario: Edit individual client email address
    Given a client exists with name "Email Edit" and mobile "9800003333"
    When I click edit on client "Email Edit"
    And I update the client email to "emailedit.updated@test.com"
    And I submit the client form
    Then I should see client updated successfully

  Scenario: Edit individual client mobile number
    Given a client exists with name "Mobile Edit" and mobile "9800004444"
    When I click edit on client "Mobile Edit"
    And I update the client mobile to "9800004445"
    And I submit the client form
    Then I should see client updated successfully

  Scenario: Edit individual client bank details
    Given a client exists with name "Bank Edit" and mobile "9800005555"
    When I click edit on client "Bank Edit"
    And I update the client bank details with:
      | field          | value       |
      | Bank Name      | SBI Bank    |
      | Account Number | 9876543210  |
      | IFSC Code      | SBIN0001234 |
    And I submit the client form
    Then I should see client updated successfully

  Scenario: Clearing mandatory first name field shows validation error on edit
    Given a client exists with name "Clear Field" and mobile "9800006666"
    When I click edit on client "Clear Field"
    And I clear the individual client first name
    And I submit the client form
    Then I should see individual client missing field error for "First name"

  # ═══════════════════════════════════════════════════════════════════════════
  # DELETE
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Delete a client from the list
    Given a client exists with name "Delete Me Client" and mobile "9800009999"
    When I visit the clients list page
    And I delete client "Delete Me Client"
    Then I should not see "Delete Me Client" on the clients page

  Scenario: Delete a client shows success message
    Given a client exists with name "Delete Confirm" and mobile "9800008888"
    When I visit the clients list page
    And I delete client "Delete Confirm"
    Then I should see client deleted successfully
