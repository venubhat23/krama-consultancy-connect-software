@javascript
Feature: Other Insurance Management
  As an admin
  I want to manage other types of insurance policies

  Background:
    Given I am logged in as admin
    And test prerequisites exist

  Scenario: Create other insurance with mandatory fields
    Given I am on the new other insurance page
    When I fill in the other insurance form with mandatory fields:
      | field                | value             |
      | Policy Number        | OTHER-TEST-001    |
      | Insurance Type       | Travel Insurance  |
      | Net Premium          | 5000              |
    And I select customer "Test Client" from the other client dropdown
    And I select other insurance company "LIC of India"
    And I select other policy type "New"
    And I set other policy start date to today
    And I set other policy end date to 1 year from today
    And I click "Create General Insurance"
    Then I should see "successfully created"
    And I should see "OTHER-TEST-001"

  Scenario: Other insurance mandatory field validation
    Given I am on the new other insurance page
    When I click "Create General Insurance" without filling any fields
    Then I should see other insurance validation errors

  Scenario: List other insurance policies
    When I visit the other insurance list page
    Then I should see the other insurance list page

  Scenario: Renew other insurance
    Given an other insurance policy exists and is eligible for renewal
    When I click "Renew" on that other insurance policy
    Then I should be on the new other insurance page prefilled with renewal data
