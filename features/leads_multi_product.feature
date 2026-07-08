@javascript
Feature: Lead Multi-Product Conversion and Branch-Out
  As an admin
  I want to manage leads that result in multiple insurance products,
  branch-out leads for the same customer, and non-insurance product conversions
  So that I can track every product pathway a lead can follow

  Background:
    Given I am logged in as admin
    And test prerequisites exist

  # ═══════════════════════════════════════════════════════════════════════════
  # SECTION 1: ONE LEAD → TWO INSURANCE POLICIES → TWO DIFFERENT CUSTOMERS
  # ═══════════════════════════════════════════════════════════════════════════
  # A sales campaign brings in 2 individual leads at the same time.
  # Each lead belongs to a different customer and converts to a different
  # insurance product independently.

  Scenario: Customer A lead converts to Health Insurance policy
    Given a converted lead exists for customer "Arun Mehta" with contact "9700000101" and subcategory "health"
    When I visit that lead's show page
    And I click Create Policy on the lead
    Then I should be on the health insurance creation page

  Scenario: Customer B lead converts to Life Insurance policy
    Given a converted lead exists for customer "Sunita Bose" with contact "9700000102" and subcategory "life"
    When I visit that lead's show page
    And I click Create Policy on the lead
    Then I should be on the life insurance creation page

  Scenario: Two independent insurance leads exist for two different customers
    Given a converted lead exists for customer "Arun Mehta" with contact "9700000103" and subcategory "health"
    And a second converted lead exists for customer "Sunita Bose" with contact "9700000104" and subcategory "motor"
    When I visit the leads list page
    Then I should see "Arun Mehta"
    And I should see "Sunita Bose"

  Scenario: Two insurance leads have different product subcategories in the list
    Given a lead exists with name "Health Lead User" and contact "9700000105" and category "insurance" and subcategory "health"
    And a lead exists with name "Life Lead User" and contact "9700000106" and category "insurance" and subcategory "life"
    When I visit the leads list page
    Then I should see "Health Lead User"
    And I should see "Life Lead User"

  Scenario: First customer lead is converted and second is still in pipeline
    Given a converted lead exists for customer "FirstConvert" with contact "9700000107" and subcategory "health"
    And a lead exists at stage "follow_up" with name "SecondPipeline User" and contact "9700000108"
    When I visit the leads list page
    Then I should see "FirstConvert"
    And I should see "SecondPipeline User"

  # ═══════════════════════════════════════════════════════════════════════════
  # SECTION 2: BRANCH-OUT LEAD SCENARIOS
  # Two new insurance product leads branched from the same parent lead
  # (same customer interested in multiple products)
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Branch-out lead is created from a parent lead with a new product category
    Given a converted lead exists for customer "Ramesh Branch" with contact "9700000201" and subcategory "health"
    When a branch-out lead is created from that lead with subcategory "life"
    Then the branch-out lead should exist with subcategory "life"
    And the branch-out lead should reference the parent lead

  Scenario: Branch-out lead for Motor Insurance from a Health Insurance parent lead
    Given a converted lead exists for customer "Priya Branch" with contact "9700000202" and subcategory "health"
    When a branch-out lead is created from that lead with subcategory "motor"
    Then the branch-out lead should exist with subcategory "motor"
    And the branch-out lead should be at stage "lead_generated"

  Scenario: Two branch-out leads from the same parent lead — different products
    Given a converted lead exists for customer "Kavita Dual" with contact "9700000203" and subcategory "health"
    When a branch-out lead is created from that lead with subcategory "life"
    And a branch-out lead is created from that lead with subcategory "motor"
    Then the parent lead should have 2 branch-out leads

  Scenario: Branch-out lead shows parent lead reference
    Given a converted lead exists for customer "Branchref User" with contact "9700000204" and subcategory "health"
    When a branch-out lead is created from that lead with subcategory "general"
    Then the branch-out lead should reference the parent lead

  Scenario: Branch-out lead can advance through the stage pipeline independently
    Given a converted lead exists for customer "Pipeline Branch" with contact "9700000205" and subcategory "health"
    When a branch-out lead is created from that lead with subcategory "life"
    And I visit the branch-out lead's show page
    And I advance the lead to the next stage
    Then the lead stage should be "Consultation Scheduled"

  Scenario: Branch-out life insurance lead converts to policy independently
    Given a converted lead exists for customer "Policy Branch" with contact "9700000206" and subcategory "health"
    When a branch-out lead is created from that lead with subcategory "life"
    And the branch-out lead is marked as converted
    And I visit the branch-out lead's show page
    And I click Create Policy on the lead
    Then I should be on the life insurance creation page

  # ═══════════════════════════════════════════════════════════════════════════
  # SECTION 3: 2 CUSTOMERS × 2–3 OTHER PRODUCTS (TRAVEL, INVESTMENT)
  # Testing which leads are converted and which remain in the pipeline
  # ═══════════════════════════════════════════════════════════════════════════

  # ── Customer 1: Travel (converted) + Investment (not yet converted) ────────

  Scenario: Customer 1 travel insurance lead is converted
    Given a converted lead exists with insurance subcategory "travel" and contact "9700000301"
    When I visit that lead's show page
    And I click Create Policy on the lead
    Then I should be on the other insurance creation page

  Scenario: Customer 1 investment lead is still in pipeline — not converted
    Given a lead exists at stage "follow_up" with name "Invest Cust1" and contact "9700000302" and category "investments" and subcategory "mutual_fund"
    When I visit that lead's show page
    Then I should see the lead stage badge
    And the lead should not be converted

  Scenario: Customer 1 has two leads — one converted, one in pipeline
    Given a converted lead exists with insurance subcategory "travel" and contact "9700000303"
    And a lead exists at stage "lead_generated" with name "Invest Pending" and contact "9700000304" and category "investments" and subcategory "mutual_fund"
    When I visit the leads list page
    Then I should see converted and non-converted leads in the list

  # ── Customer 2: Travel (converted) + Investment (not yet) + Credit Card (not yet) ──

  Scenario: Customer 2 travel insurance lead is converted
    Given a converted lead exists with insurance subcategory "travel" and contact "9700000311"
    When I visit that lead's show page
    And I click Create Policy on the lead
    Then I should be on the other insurance creation page

  Scenario: Customer 2 investment lead is not converted
    Given a lead exists at stage "consultation_scheduled" with name "Invest Cust2" and contact "9700000312" and category "investments" and subcategory "fixed_deposit"
    When I visit that lead's show page
    Then the lead should not be converted
    And I should see the lead stage badge

  Scenario: Customer 2 credit card lead is not converted
    Given a lead exists at stage "one_on_one" with name "CreditCard Cust2" and contact "9700000313" and category "credit_card" and subcategory "rewards"
    When I visit that lead's show page
    Then the lead should not be converted
    And I should see the lead stage badge

  Scenario: Customer 2 has three leads with different conversion statuses
    Given a converted lead exists with insurance subcategory "travel" and contact "9700000314"
    And a lead exists at stage "follow_up" with name "C2 Investment" and contact "9700000315" and category "investments" and subcategory "mutual_fund"
    And a lead exists at stage "lead_generated" with name "C2 CreditCard" and contact "9700000316" and category "credit_card" and subcategory "rewards"
    When I visit the leads list page
    Then I should see "C2 Investment"
    And I should see "C2 CreditCard"

  # ── Cross-product conversion status checks ─────────────────────────────────

  Scenario: Travel lead redirects to Other Insurance form when converting
    Given a converted lead exists with insurance subcategory "travel" and contact "9700000321"
    When I visit that lead's show page
    And I click Create Policy on the lead
    Then I should be on the other insurance creation page

  Scenario: Investment lead — Mutual Fund — does not show Create Policy button when not converted
    Given a lead exists at stage "follow_up_successful" with name "MutualFund Check" and contact "9700000322" and category "investments" and subcategory "mutual_fund"
    When I visit that lead's show page
    Then the lead should not be converted

  Scenario: Investment lead can be advanced to converted stage
    Given a lead exists at stage "follow_up_successful" with name "Invest Convert" and contact "9700000323" and category "investments" and subcategory "mutual_fund"
    When I visit that lead's show page
    And I update lead stage to "converted"
    Then the lead stage should be "Converted"

  Scenario: Travel lead pipeline → converted through all stages
    Given a lead exists at stage "lead_generated" with name "Travel Pipeline" and contact "9700000330" and category "insurance" and subcategory "travel"
    When I visit that lead's show page
    And I advance the lead to the next stage
    Then the lead stage should be "Consultation Scheduled"
    When I advance the lead to the next stage
    Then the lead stage should be "One on One"
    When I advance the lead to the next stage
    Then the lead stage should be "Follow Up"
    When I update lead stage to "follow_up_successful"
    Then the lead stage should be "Follow Up Successful"
    When I update lead stage to "converted"
    Then the lead stage should be "Converted"

  Scenario: Investment lead — not interested — closed without converting
    Given a lead exists at stage "lead_generated" with name "Invest NotInt" and contact "9700000331" and category "investments" and subcategory "mutual_fund"
    When I visit that lead's show page
    And I mark the lead as not interested
    Then I should see "Not Interested"
    When I close the lead
    Then the lead should be at stage "lead_closed"

  Scenario: Leads list shows correct count for converted vs non-converted
    Given a converted lead exists with insurance subcategory "travel" and contact "9700000340"
    And a lead exists at stage "follow_up" with name "NotYet Convert" and contact "9700000341"
    When I visit the leads converted tab
    Then the leads page should show converted leads only
