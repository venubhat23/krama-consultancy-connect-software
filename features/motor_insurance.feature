@javascript
Feature: Motor Insurance Management
  As an admin
  I want to manage motor insurance policies

  Background:
    Given I am logged in as admin
    And test prerequisites exist

  Scenario: Create motor insurance with all mandatory fields
    Given I am on the new motor insurance page
    When I fill in the motor insurance form with mandatory fields:
      | field                | value            |
      | Policy Number        | MOTOR-TEST-001   |
      | Net Premium          | 15000            |
      | Vehicle Number       | MH01AB1234       |
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
    And I should see "MOTOR-TEST-001"

  Scenario: Motor insurance mandatory field validation
    Given I am on the new motor insurance page
    When I click "Create Motor Insurance" without filling any fields
    Then I should see motor insurance validation errors

  Scenario Outline: Create motor insurance for different vehicle types
    Given I am on the new motor insurance page
    When I fill in the motor insurance form with mandatory fields:
      | field          | value              |
      | Policy Number  | MOTOR-<class>-001  |
      | Net Premium    | 12000              |
      | Vehicle Number | MH02CD5678         |
    And I select customer "Test Client" from the motor client dropdown
    And I select vehicle type "Old Vehicle"
    And I select class of vehicle "<class>"
    And I select motor insurance type "Comprehensive"
    And I select motor insurance company "LIC of India"
    And I set motor policy start date to today
    And I set motor policy end date to 1 year from today
    And I click "Create Motor Insurance"
    Then I should see "Motor insurance policy was successfully created"

    Examples:
      | class          |
      | Private Car    |
      | Two Wheeler    |
      | Goods Vehicle  |

  Scenario Outline: Create motor insurance with different insurance types
    Given I am on the new motor insurance page
    When I fill in the motor insurance form with mandatory fields:
      | field          | value               |
      | Policy Number  | MOTOR-<itype>-001   |
      | Net Premium    | 10000               |
      | Vehicle Number | MH03EF9012          |
    And I select customer "Test Client" from the motor client dropdown
    And I select vehicle type "Old Vehicle"
    And I select class of vehicle "Private Car"
    And I select motor insurance type "<itype>"
    And I select motor insurance company "LIC of India"
    And I set motor policy start date to today
    And I set motor policy end date to 1 year from today
    And I click "Create Motor Insurance"
    Then I should see "Motor insurance policy was successfully created"

    Examples:
      | itype           |
      | Comprehensive   |
      | Third Party     |
      | Own Damage      |

  Scenario: Renew motor insurance
    Given a motor insurance policy "MOTOR-ORIG-001" exists and is eligible for renewal
    When I click "Renew" on that motor policy
    Then I should be on the new motor insurance page prefilled with renewal data

  Scenario: List motor insurance policies
    When I visit the motor insurance list page
    Then I should see the motor insurance list page
