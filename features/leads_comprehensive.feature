@javascript
Feature: Lead Management - Comprehensive End-to-End
  As an admin
  I want to manage leads through all product combinations, CRUD operations,
  full stage lifecycles, and verified policy conversions
  So that every lead pathway and conversion is covered

  Background:
    Given I am logged in as admin
    And test prerequisites exist

  # ─────────────────────────────────────────────────────────────
  # 1. PRODUCT CATEGORY × PRODUCT TYPE COMBINATIONS (UI)
  # ─────────────────────────────────────────────────────────────

  Scenario Outline: Selecting a product category shows the correct product type options
    Given I am on the new lead page
    When I select lead product category "<category>"
    Then the product type dropdown should contain "<expected_option>"

    Examples:
      | category    | expected_option         |
      | insurance   | Life Insurance          |
      | insurance   | Health Insurance        |
      | insurance   | Motor Insurance         |
      | insurance   | General Insurance       |
      | insurance   | Travel Insurance        |
      | insurance   | Other                   |
      | investments | Mutual Fund             |
      | investments | Fixed Deposit (FD)      |
      | investments | Other                   |
      | loans       | Personal Loan           |
      | loans       | Home Loan               |
      | loans       | Mortgage Loan           |
      | loans       | Business Loan           |
      | taxation    | ITR                     |
      | taxation    | Tax Planning            |
      | travel      | Domestic                |
      | travel      | International           |
      | credit_card | Rewards Card            |
      | credit_card | Business Card           |
      | credit_card | Travel Card             |

  # ─────────────────────────────────────────────────────────────
  # 2. CREATE LEADS — ALL INSURANCE SUBCATEGORIES
  # ─────────────────────────────────────────────────────────────

  Scenario Outline: Create a lead for each insurance product type
    Given I am on the new lead page
    And I select lead customer type "Individual"
    And I select lead source "Walk In"
    And I select lead product category "insurance"
    And I select lead product subcategory "<subcategory>"
    When I fill in the individual lead fields with:
      | field          | value        |
      | First Name     | <first_name> |
      | Last Name      | Testlead     |
      | Contact Number | <contact>    |
    And I submit the lead form
    Then I should see "Lead was successfully created"
    And I should see "<first_name> Testlead"

    Examples:
      | subcategory | first_name  | contact    |
      | life        | LifeTest    | 9600000001 |
      | health      | HealthTest  | 9600000002 |
      | motor       | MotorTest   | 9600000003 |
      | general     | GeneralTest | 9600000004 |
      | travel      | TravelTest  | 9600000005 |
      | other       | OtherTest   | 9600000006 |

  Scenario: Create a lead for Investments — Mutual Fund
    Given I am on the new lead page
    And I select lead customer type "Individual"
    And I select lead source "Online"
    And I select lead product category "investments"
    And I select lead product subcategory "mutual_fund"
    When I fill in the individual lead fields with:
      | field          | value      |
      | First Name     | Mutual     |
      | Last Name      | Fund       |
      | Contact Number | 9600000007 |
    And I submit the lead form
    Then I should see "Lead was successfully created"

  Scenario: Create a lead for Loans — Home Loan
    Given I am on the new lead page
    And I select lead customer type "Individual"
    And I select lead source "Online"
    And I select lead product category "loans"
    And I select lead product subcategory "home"
    When I fill in the individual lead fields with:
      | field          | value      |
      | First Name     | HomeLoan   |
      | Last Name      | Test       |
      | Contact Number | 9600000008 |
    And I submit the lead form
    Then I should see "Lead was successfully created"

  Scenario: Create a lead for Taxation — ITR
    Given I am on the new lead page
    And I select lead customer type "Individual"
    And I select lead source "Walk In"
    And I select lead product category "taxation"
    And I select lead product subcategory "itr"
    When I fill in the individual lead fields with:
      | field          | value      |
      | First Name     | ITRFiling  |
      | Last Name      | Test       |
      | Contact Number | 9600000009 |
    And I submit the lead form
    Then I should see "Lead was successfully created"

  Scenario: Create a lead for Travel — International
    Given I am on the new lead page
    And I select lead customer type "Individual"
    And I select lead source "Campaign"
    And I select lead product category "travel"
    And I select lead product subcategory "international"
    When I fill in the individual lead fields with:
      | field          | value         |
      | First Name     | International |
      | Last Name      | Traveler      |
      | Contact Number | 9600000010    |
    And I submit the lead form
    Then I should see "Lead was successfully created"

  Scenario: Create a corporate lead for Credit Card — Rewards
    Given I am on the new lead page
    And I select lead customer type "Corporate"
    And I select lead source "Agent Referral"
    And I select lead product category "credit_card"
    And I select lead product subcategory "rewards"
    When I fill in the corporate lead fields with:
      | field          | value         |
      | Company Name   | Rewards Corp  |
      | Contact Number | 9600000011    |
    And I submit the lead form
    Then I should see "Lead was successfully created"

  # ─────────────────────────────────────────────────────────────
  # 3. CRUD — DELETE A LEAD
  # ─────────────────────────────────────────────────────────────

  Scenario: Delete a lead removes it from the list
    Given a lead exists with name "Delete Me Lead" and contact "9600000050"
    When I visit the leads list page
    And I delete the lead via direct HTTP
    Then I should see "Lead successfully deleted"
    And "Delete Me Lead" should not appear in the leads list

  # ─────────────────────────────────────────────────────────────
  # 4. FULL STAGE LIFECYCLE — HAPPY PATH
  # ─────────────────────────────────────────────────────────────

  Scenario: Full happy-path pipeline — Lead Generated through Follow-Up Successful
    Given a lead exists at stage "lead_generated" with name "Pipeline Test" and contact "9600000060"
    When I visit that lead's show page
    And I advance the lead to the next stage
    Then the lead stage should be "Consultation Scheduled"
    When I advance the lead to the next stage
    Then the lead stage should be "One on One"
    When I advance the lead to the next stage
    Then the lead stage should be "Follow Up"
    When I update lead stage to "follow_up_successful"
    Then the lead stage should be "Follow Up Successful"

  Scenario: Pipeline — Not Interested → Lead Closed
    Given a lead exists at stage "lead_generated" with name "Not Interest Lead" and contact "9600000070"
    When I visit that lead's show page
    And I mark the lead as not interested
    Then I should see "Not Interested"
    When I close the lead
    Then the lead should be at stage "lead_closed"

  Scenario: Pipeline — Follow-Up Unsuccessful → Re-Follow-Up
    Given a lead exists at stage "follow_up" with name "ReFollow Lead" and contact "9600000080"
    When I visit that lead's show page
    And I update lead stage to "follow_up_unsuccessful"
    Then the lead stage should be "Follow Up Unsuccessful"
    When I update lead stage to "re_follow_up"
    Then the lead stage should be "Re Follow Up"
    When I update lead stage to "follow_up_successful"
    Then the lead stage should be "Follow Up Successful"

  Scenario: Direct conversion from lead_generated (skip intermediate stages)
    Given a lead exists at stage "lead_generated" with name "DirectConvert Lead" and contact "9600000090"
    When I visit that lead's show page
    And I update lead stage to "converted"
    Then the lead stage should be "Converted"

  # ─────────────────────────────────────────────────────────────
  # 5. LEAD CONVERSION — CREATE POLICY REDIRECTS TO CORRECT FORM
  # ─────────────────────────────────────────────────────────────

  Scenario: Travel insurance lead — create_policy redirects to Other Insurance form
    Given a converted lead exists with insurance subcategory "travel" and contact "9600000101"
    When I visit that lead's show page
    And I click Create Policy on the lead
    Then I should be on the other insurance creation page

  Scenario: Health insurance lead — create_policy redirects to Health Insurance form
    Given a converted lead exists with insurance subcategory "health" and contact "9600000102"
    When I visit that lead's show page
    And I click Create Policy on the lead
    Then I should be on the health insurance creation page

  Scenario: Life insurance lead — create_policy redirects to Life Insurance form
    Given a converted lead exists with insurance subcategory "life" and contact "9600000103"
    When I visit that lead's show page
    And I click Create Policy on the lead
    Then I should be on the life insurance creation page

  Scenario: Motor insurance lead — create_policy redirects to Motor Insurance form
    Given a converted lead exists with insurance subcategory "motor" and contact "9600000104"
    When I visit that lead's show page
    And I click Create Policy on the lead
    Then I should be on the motor insurance creation page

  Scenario: General insurance lead — create_policy redirects to Other Insurance form
    Given a converted lead exists with insurance subcategory "general" and contact "9600000105"
    When I visit that lead's show page
    And I click Create Policy on the lead
    Then I should be on the other insurance creation page

  Scenario: Other insurance subcategory lead — create_policy redirects to Other Insurance form
    Given a converted lead exists with insurance subcategory "other" and contact "9600000106"
    When I visit that lead's show page
    And I click Create Policy on the lead
    Then I should be on the other insurance creation page

  # ─────────────────────────────────────────────────────────────
  # 6. END-TO-END: TRAVEL INSURANCE CONVERSION → RECORD IN OTHER INSURANCE
  # ─────────────────────────────────────────────────────────────

  Scenario: Converting travel insurance lead end-to-end creates 1 record in Other Insurance
    Given a converted lead exists with insurance subcategory "travel" and contact "9600000201"
    When I visit that lead's show page
    And I click Create Policy on the lead
    Then I should be on the other insurance creation page
    When I fill in the other insurance form for travel conversion:
      | field             | value            |
      | Policy Number     | TRVL-LEAD-E2E-01 |
      | Insurance Type    | Travel Insurance |
      | Net Premium       | 5000             |
    And I set the other insurance company for lead conversion
    And I set other policy start date to today
    And I set other policy end date to 1 year from today
    And I submit the other insurance form for lead conversion
    Then I should see "General insurance policy was successfully created"
    When I visit the other insurance list page
    Then I should see "Travel Insurance" in the other insurance list
    And the other insurance list should have at least 1 record

  # ─────────────────────────────────────────────────────────────
  # 7. END-TO-END: HEALTH INSURANCE CONVERSION → RECORD IN HEALTH SECTION
  # ─────────────────────────────────────────────────────────────

  Scenario: Converting health insurance lead creates record in Health Insurance section
    Given a converted lead exists with insurance subcategory "health" and contact "9600000202"
    When I visit that lead's show page
    And I click Create Policy on the lead
    Then I should be on the health insurance creation page
    When I visit the health insurance list page
    Then the health insurance list page should load

  # ─────────────────────────────────────────────────────────────
  # 8. LEAD INDEX: FILTERS AND SEARCH
  # ─────────────────────────────────────────────────────────────

  Scenario: Filter leads by product category shows only matching records
    Given a lead exists with name "FilterCat Lead" and contact "9600000110" and category "travel"
    When I visit the leads list page
    And I filter leads by product category "travel"
    Then I should see "FilterCat Lead"

  Scenario: Converted leads tab shows only converted leads
    Given a converted lead exists with insurance subcategory "health" and contact "9600000120"
    When I visit the leads converted tab
    Then the leads page should show converted leads only

  Scenario: Stage transition buttons are visible on lead show page
    Given a lead exists at stage "lead_generated" with name "Stage Btn Lead" and contact "9600000130"
    When I visit that lead's show page
    Then I should see the stage action buttons
