@javascript
Feature: Lead Management
  As an admin
  I want to manage leads through their lifecycle
  So that I can track prospects and convert them to customers

  Background:
    Given I am logged in as admin
    And test prerequisites exist

  Scenario: Create a new individual lead with all mandatory fields
    Given I am on the new lead page
    And I select lead customer type "Individual"
    And I select lead source "Walk In"
    And I select lead product category "Insurance"
    And I select lead product subcategory "Health"
    When I fill in the individual lead fields with:
      | field          | value      |
      | First Name     | Ramesh     |
      | Last Name      | Kumar      |
      | Contact Number | 9876543210 |
    And I submit the lead form
    Then I should see "Lead was successfully created"
    And I should see "Ramesh Kumar"

  Scenario: Create a new corporate lead
    Given I am on the new lead page
    And I select lead customer type "Corporate"
    And I select lead source "Online"
    And I select lead product category "Insurance"
    And I select lead product subcategory "Health"
    When I fill in the corporate lead fields with:
      | field          | value        |
      | Company Name   | Acme Pvt Ltd |
      | Contact Number | 9988776655   |
    And I submit the lead form
    Then I should see "Lead was successfully created"
    And I should see "Acme Pvt Ltd"

  Scenario: Lead mandatory field validation
    Given I am on the new lead page
    When I submit the lead form without filling any fields
    Then I should see lead validation errors

  Scenario: List leads on index page
    Given a lead exists with name "Priya Sharma" and contact "9123456780"
    When I visit the leads list page
    Then I should see "Priya Sharma"

  Scenario: View lead details
    Given a lead exists with name "Suresh Nair" and contact "9000011111"
    When I visit that lead's show page
    Then I should see "Suresh Nair"
    And I should see the lead stage badge

  Scenario: Advance lead from Lead Generated to Consultation Scheduled
    Given a lead exists at stage "lead_generated" with name "Amit Patel" and contact "9111122222"
    When I visit that lead's show page
    And I advance the lead to the next stage
    Then the lead stage should be "Consultation Scheduled"

  Scenario: Mark lead as Not Interested
    Given a lead exists at stage "lead_generated" with name "Geeta Singh" and contact "9222233333"
    When I visit that lead's show page
    And I mark the lead as not interested
    Then I should see "Not Interested"

  Scenario: Close a lead
    Given a lead exists at stage "not_interested" with name "Vivek Rao" and contact "9333344444"
    When I visit that lead's show page
    And I close the lead
    Then the lead should be at stage "lead_closed"

  Scenario: Search for a lead by name
    Given a lead exists with name "Deepa Menon" and contact "9444455555"
    When I visit the leads list page
    And I search leads for "Deepa"
    Then I should see "Deepa Menon"

  Scenario: Filter leads by stage
    Given a lead exists at stage "follow_up" with name "Kiran Joshi" and contact "9555566666"
    When I visit the leads list page
    And I filter leads by stage "Follow-Up"
    Then I should see "Kiran Joshi"

  Scenario: Edit a lead
    Given a lead exists with name "Arjun Das" and contact "9666677777"
    When I visit that lead's edit page
    And I update the lead first name to "Arjun Updated"
    And I click "Update Lead"
    Then I should see "Lead was successfully updated"
