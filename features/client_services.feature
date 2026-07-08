@javascript
Feature: Client Services CRUD — Investments, Taxation, Loans, Travel, Credit Card
  As an admin
  I want to create, view, edit, and delete service records for all product types
  So that all service categories are fully managed end-to-end

  Background:
    Given I am logged in as admin
    And test prerequisites exist
    And a client service customer exists

  # ═══════════════════════════════════════════════════════════════════════════
  # LIST — all service types show the records list page
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario Outline: View list page for each service type
    When I visit the client services list for "<service_type>"
    Then I should be on the client services list page

    Examples:
      | service_type              |
      | investments_mutual_fund   |
      | investments_fd            |
      | investments_other         |
      | taxation_itr              |
      | taxation_tax_planning     |
      | loans_personal            |
      | loans_home                |
      | loans_mortgage            |
      | loans_business            |
      | travel_domestic           |
      | travel_international      |
      | credit_card_rewards       |
      | credit_card_business      |
      | credit_card_travel        |

  # ═══════════════════════════════════════════════════════════════════════════
  # CREATE — one representative per category
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario Outline: Create a service record for each type
    When I visit the new client service page for "<service_type>"
    And I fill in the minimum client service fields
    And I submit the client service form
    Then I should see "<success_message>"
    And the last created client service should be marked as admin added

    Examples:
      | service_type              | success_message                      |
      | investments_mutual_fund   | Mutual Fund record created           |
      | investments_fd            | Fixed Deposit (FD) record created    |
      | investments_other         | Other Investment record created      |
      | taxation_itr              | ITR Filing record created            |
      | taxation_tax_planning     | Tax Planning record created          |
      | loans_personal            | Personal Loan record created         |
      | loans_home                | Home Loan record created             |
      | loans_mortgage            | Mortgage Loan record created         |
      | loans_business            | Business Loan record created         |
      | travel_domestic           | Domestic Travel record created       |
      | travel_international      | International Travel record created  |
      | credit_card_rewards       | Rewards Card record created          |
      | credit_card_business      | Business Card record created         |
      | credit_card_travel        | Travel Card record created           |

  # ═══════════════════════════════════════════════════════════════════════════
  # CREATE — lead → customer flow tags record as drwise
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario Outline: Record created via lead to customer flow is tagged as drwise
    Given a lead exists with a converted customer
    When I visit the new client service page with lead and customer params for "<service_type>"
    And I fill in the minimum client service fields
    And I submit the client service form
    Then the last created client service should be marked as admin added

    Examples:
      | service_type              |
      | investments_mutual_fund   |
      | taxation_itr              |
      | loans_personal            |
      | travel_domestic           |
      | credit_card_rewards       |

  # ═══════════════════════════════════════════════════════════════════════════
  # VIEW (SHOW)
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario Outline: View a service record
    Given a client service record exists for "<service_type>"
    When I visit the client services list for "<service_type>"
    And I click view on the first client service record
    Then I should be on the client service show page

    Examples:
      | service_type              |
      | investments_mutual_fund   |
      | investments_fd            |
      | investments_other         |
      | taxation_itr              |
      | taxation_tax_planning     |
      | loans_personal            |
      | loans_home                |
      | loans_mortgage            |
      | loans_business            |
      | travel_domestic           |
      | travel_international      |
      | credit_card_rewards       |
      | credit_card_business      |
      | credit_card_travel        |

  # ═══════════════════════════════════════════════════════════════════════════
  # EDIT / UPDATE
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario Outline: Edit a service record
    Given a client service record exists for "<service_type>"
    When I visit the client services list for "<service_type>"
    And I click edit on the first client service record
    And I update the client service amount to "9999"
    And I submit the client service form
    Then I should see "<success_message>"

    Examples:
      | service_type              | success_message                      |
      | investments_mutual_fund   | Mutual Fund record updated           |
      | investments_fd            | Fixed Deposit (FD) record updated    |
      | investments_other         | Other Investment record updated      |
      | taxation_itr              | ITR Filing record updated            |
      | taxation_tax_planning     | Tax Planning record updated          |
      | loans_personal            | Personal Loan record updated         |
      | loans_home                | Home Loan record updated             |
      | loans_mortgage            | Mortgage Loan record updated         |
      | loans_business            | Business Loan record updated         |
      | travel_domestic           | Domestic Travel record updated       |
      | travel_international      | International Travel record updated  |
      | credit_card_rewards       | Rewards Card record updated          |
      | credit_card_business      | Business Card record updated         |
      | credit_card_travel        | Travel Card record updated           |

  # ═══════════════════════════════════════════════════════════════════════════
  # DELETE
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario Outline: Delete a service record
    Given a client service record exists for "<service_type>"
    When I visit the client services list for "<service_type>"
    And I delete the first client service record
    Then I should see "Record deleted successfully"

    Examples:
      | service_type              |
      | investments_mutual_fund   |
      | investments_fd            |
      | investments_other         |
      | taxation_itr              |
      | taxation_tax_planning     |
      | loans_personal            |
      | loans_home                |
      | loans_mortgage            |
      | loans_business            |
      | travel_domestic           |
      | travel_international      |
      | credit_card_rewards       |
      | credit_card_business      |
      | credit_card_travel        |

  # ═══════════════════════════════════════════════════════════════════════════
  # COMMISSION CALCULATION
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Investor actual amount updates when investor percentage changes
    When I visit the new client service page for "investments_mutual_fund"
    And I set the investment amount to "10000"
    And I set the main agent commission percentage to "10"
    And I set the investor commission percentage to "2"
    Then the investor actual amount should equal "200.00"

  Scenario: Company actual amount updates when company percentage changes
    When I visit the new client service page for "investments_mutual_fund"
    And I set the investment amount to "10000"
    And I set the main agent commission percentage to "10"
    And I set the company expenses percentage to "3"
    Then the company actual amount should equal "300.00"

  Scenario: Profit recalculates when investor and company percentages change
    When I visit the new client service page for "investments_mutual_fund"
    And I set the investment amount to "10000"
    And I set the main agent commission percentage to "10"
    And I set the investor commission percentage to "2"
    And I set the company expenses percentage to "1"
    Then the profit percentage should equal "7.00"
    And the profit amount should equal "700.00"
