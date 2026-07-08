@javascript
Feature: Customer Show Page — All Sections
  As an admin
  I want to see comprehensive customer information organized by section
  So that I can quickly access personal, financial, insurance, and lead data for any client

  Background:
    Given I am logged in as admin
    And test prerequisites exist

  # ═══════════════════════════════════════════════════════════════════════════
  # PAGE HEADER
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Header shows customer full name
    Given a full individual customer exists with mobile "9601001001"
    When I visit the customer show page for mobile "9601001001"
    Then I should see the customer full name in the header

  Scenario: Header shows ACTIVE status badge for active customer
    Given a full individual customer exists with mobile "9601001002"
    When I visit the customer show page for mobile "9601001002"
    Then I should see "ACTIVE"

  Scenario: Header shows INACTIVE status badge for deactivated customer
    Given a deactivated individual customer exists with mobile "9601001003"
    When I visit the customer show page for mobile "9601001003"
    Then I should see "INACTIVE"

  Scenario: Header shows Edit Client button
    Given a full individual customer exists with mobile "9601001004"
    When I visit the customer show page for mobile "9601001004"
    Then I should see "Edit Client"

  Scenario: Header shows Create Insurance dropdown button
    Given a full individual customer exists with mobile "9601001005"
    When I visit the customer show page for mobile "9601001005"
    Then I should see "Create Insurance"

  Scenario: Header shows Back to Customers link
    Given a full individual customer exists with mobile "9601001006"
    When I visit the customer show page for mobile "9601001006"
    Then I should see "Back to Customers"

  # ═══════════════════════════════════════════════════════════════════════════
  # BASIC INFORMATION SECTION
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Basic Information section header is visible
    Given a full individual customer exists with mobile "9601002001"
    When I visit the customer show page for mobile "9601002001"
    Then I should see "Basic Information"

  Scenario: Expanding Basic Information shows customer first name
    Given a full individual customer exists with mobile "9601002002"
    When I visit the customer show page for mobile "9601002002"
    And I expand the customer section "Basic Information"
    Then I should see the customer's first name in the section

  Scenario: Expanding Basic Information shows mobile number
    Given a full individual customer exists with mobile "9601002003"
    When I visit the customer show page for mobile "9601002003"
    And I expand the customer section "Basic Information"
    Then I should see "9601002003"

  Scenario: Expanding Basic Information shows email address
    Given a full individual customer with email "basicinfo.show@test.com" and mobile "9601002004"
    When I visit the customer show page for mobile "9601002004"
    And I expand the customer section "Basic Information"
    Then I should see "basicinfo.show@test.com"

  Scenario: Expanding Basic Information shows gender
    Given a full individual customer with gender "male" and mobile "9601002005"
    When I visit the customer show page for mobile "9601002005"
    And I expand the customer section "Basic Information"
    Then I should see "Male"

  # ═══════════════════════════════════════════════════════════════════════════
  # PROFESSIONAL INFORMATION SECTION
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Professional Information section header is visible
    Given a full individual customer exists with mobile "9601003001"
    When I visit the customer show page for mobile "9601003001"
    Then I should see "Professional Information"

  Scenario: Expanding Professional Information shows occupation
    Given a full individual customer with occupation "Software Engineer" and mobile "9601003002"
    When I visit the customer show page for mobile "9601003002"
    And I expand the customer section "Professional Information"
    Then I should see "Software Engineer"

  Scenario: Expanding Professional Information shows annual income
    Given a full individual customer with annual income "500000" and mobile "9601003003"
    When I visit the customer show page for mobile "9601003003"
    And I expand the customer section "Professional Information"
    Then I should see customer annual income in section

  # ═══════════════════════════════════════════════════════════════════════════
  # ADDRESS INFORMATION SECTION
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Address Information section header is visible
    Given a full individual customer exists with mobile "9601004001"
    When I visit the customer show page for mobile "9601004001"
    Then I should see "Address Information"

  Scenario: Expanding Address Information shows city when present
    Given a full individual customer with city "Mumbai" and mobile "9601004002"
    When I visit the customer show page for mobile "9601004002"
    And I expand the customer section "Address Information"
    Then I should see "Mumbai"

  Scenario: Expanding Address Information shows state when present
    Given a full individual customer with state "Maharashtra" and mobile "9601004003"
    When I visit the customer show page for mobile "9601004003"
    And I expand the customer section "Address Information"
    Then I should see "Maharashtra"

  Scenario: Expanding Address Information shows pincode when present
    Given a full individual customer with pincode "400001" and mobile "9601004004"
    When I visit the customer show page for mobile "9601004004"
    And I expand the customer section "Address Information"
    Then I should see "400001"

  # ═══════════════════════════════════════════════════════════════════════════
  # PRODUCT & INSURANCE INFORMATION SECTION
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Product and Insurance Information section header is visible
    Given a full individual customer exists with mobile "9601005001"
    When I visit the customer show page for mobile "9601005001"
    Then I should see "Product & Insurance Information"

  Scenario: Expanding Product section shows health insurance policy count
    Given a full individual customer exists with mobile "9601005002"
    When I visit the customer show page for mobile "9601005002"
    And I expand the customer section "Product & Insurance Information"
    Then I should see "Health Insurance"

  Scenario: Expanding Product section shows affiliate as Direct Customer when not assigned
    Given a full individual customer exists with mobile "9601005003"
    When I visit the customer show page for mobile "9601005003"
    And I expand the customer section "Product & Insurance Information"
    Then I should see "Direct Customer"

  # ═══════════════════════════════════════════════════════════════════════════
  # NOMINEE INFORMATION SECTION
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Nominee Information section header is visible
    Given a full individual customer exists with mobile "9601006001"
    When I visit the customer show page for mobile "9601006001"
    Then I should see "Nominee Information"

  Scenario: Expanding Nominee Information shows nominee name when present
    Given a full individual customer with nominee "Meena Testuser" and mobile "9601006002"
    When I visit the customer show page for mobile "9601006002"
    And I expand the customer section "Nominee Information"
    Then I should see "Meena Testuser"

  Scenario: Expanding Nominee Information shows nominee relation
    Given a full individual customer with nominee "Spouse Nominee" and mobile "9601006003"
    When I visit the customer show page for mobile "9601006003"
    And I expand the customer section "Nominee Information"
    Then I should see "Spouse Nominee"

  Scenario: Minimal individual customer nominee section is visible
    Given a minimal individual customer exists with mobile "9601006004"
    When I visit the customer show page for mobile "9601006004"
    And I expand the customer section "Nominee Information"
    Then I should see "Minimal Nominee"

  # ═══════════════════════════════════════════════════════════════════════════
  # FINANCIAL INFORMATION SECTION
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Financial Information section header is visible
    Given a full individual customer exists with mobile "9601007001"
    When I visit the customer show page for mobile "9601007001"
    Then I should see "Financial Information"

  Scenario: Expanding Financial Information shows annual income when present
    Given a full individual customer with annual income "750000" and mobile "9601007002"
    When I visit the customer show page for mobile "9601007002"
    And I expand the customer section "Financial Information"
    Then I should see customer annual income in section

  # ═══════════════════════════════════════════════════════════════════════════
  # FAMILY MEMBERS SECTION
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Family Members section header is visible
    Given a full individual customer exists with mobile "9601008001"
    When I visit the customer show page for mobile "9601008001"
    Then I should see "Family Members"

  Scenario: Family Members section shows member count in header
    Given a customer with a family member exists with mobile "9601008002"
    When I visit the customer show page for mobile "9601008002"
    Then I should see "1 Members"

  Scenario: Expanding Family Members shows the member name
    Given a customer with a family member named "Sunita Kumar" exists with mobile "9601008003"
    When I visit the customer show page for mobile "9601008003"
    And I expand the customer section "Family Members"
    Then I should see "Sunita Kumar"

  Scenario: Customer without family members shows empty state
    Given a full individual customer exists with mobile "9601008004"
    When I visit the customer show page for mobile "9601008004"
    And I expand the customer section "Family Members"
    Then I should see "No family members added yet"

  Scenario: Expanding Family Members shows relationship badge
    Given a customer with a family member exists with mobile "9601008005"
    When I visit the customer show page for mobile "9601008005"
    And I expand the customer section "Family Members"
    Then I should see "Spouse"

  # ═══════════════════════════════════════════════════════════════════════════
  # DOCUMENT LIBRARY SECTION
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Document Library section header is visible
    Given a full individual customer exists with mobile "9601009001"
    When I visit the customer show page for mobile "9601009001"
    Then I should see "Document Library"

  Scenario: Document Library section shows document count
    Given a full individual customer exists with mobile "9601009002"
    When I visit the customer show page for mobile "9601009002"
    Then I should see "Document Library (0)"

  # ═══════════════════════════════════════════════════════════════════════════
  # HEALTH INSURANCE SECTION
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Health Insurance section header is visible on show page
    Given a full individual customer exists with mobile "9601010001"
    When I visit the customer show page for mobile "9601010001"
    Then I should see "Health Insurance"

  Scenario: Customer with health policy shows it in Health Insurance section
    Given a customer with a health insurance policy exists with mobile "9601010002"
    When I visit the customer show page for mobile "9601010002"
    And I expand the customer section "Health Insurance"
    Then I should see the health insurance company name

  Scenario: Customer without health policy shows empty state in Health Insurance section
    Given a full individual customer exists with mobile "9601010003"
    When I visit the customer show page for mobile "9601010003"
    And I expand the customer section "Health Insurance"
    Then I should see "No policies in this category"

  # ═══════════════════════════════════════════════════════════════════════════
  # LIFE INSURANCE SECTION
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Life Insurance section header is visible on show page
    Given a full individual customer exists with mobile "9601011001"
    When I visit the customer show page for mobile "9601011001"
    Then I should see "Life Insurance"

  Scenario: Customer without life policy shows empty state in Life Insurance section
    Given a full individual customer exists with mobile "9601011002"
    When I visit the customer show page for mobile "9601011002"
    And I expand the customer section "Life Insurance"
    Then I should see "No policies in this category"

  # ═══════════════════════════════════════════════════════════════════════════
  # MOTOR INSURANCE SECTION
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Motor Insurance section header is visible on show page
    Given a full individual customer exists with mobile "9601012001"
    When I visit the customer show page for mobile "9601012001"
    Then I should see "Motor Insurance"

  Scenario: Customer with motor policy shows it in Motor Insurance section
    Given a customer with a motor insurance policy exists with mobile "9601012002"
    When I visit the customer show page for mobile "9601012002"
    And I expand the customer section "Motor Insurance"
    Then I should see the motor insurance company name

  Scenario: Customer without motor policy shows empty state in Motor Insurance section
    Given a full individual customer exists with mobile "9601012003"
    When I visit the customer show page for mobile "9601012003"
    And I expand the customer section "Motor Insurance"
    Then I should see "No policies in this category"

  # ═══════════════════════════════════════════════════════════════════════════
  # OTHER INSURANCE SECTION
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Other Insurance section header is visible on show page
    Given a full individual customer exists with mobile "9601013001"
    When I visit the customer show page for mobile "9601013001"
    Then I should see "Other Insurance"

  Scenario: Customer without other policy shows empty state in Other Insurance section
    Given a full individual customer exists with mobile "9601013002"
    When I visit the customer show page for mobile "9601013002"
    And I expand the customer section "Other Insurance"
    Then I should see "No policies in this category"

  # ═══════════════════════════════════════════════════════════════════════════
  # EXPIRED / PAST / UPCOMING POLICY SECTIONS
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Expired Policy section header is visible
    Given a full individual customer exists with mobile "9601014001"
    When I visit the customer show page for mobile "9601014001"
    Then I should see "Expired Policy"

  Scenario: Past Policy section header is visible
    Given a full individual customer exists with mobile "9601014002"
    When I visit the customer show page for mobile "9601014002"
    Then I should see "Past Policy"

  Scenario: Upcoming Renewal Policy section header is visible
    Given a full individual customer exists with mobile "9601014003"
    When I visit the customer show page for mobile "9601014003"
    Then I should see "Upcoming Renewal Policy"

  Scenario: Upcoming Installment Policy section header is visible
    Given a full individual customer exists with mobile "9601014004"
    When I visit the customer show page for mobile "9601014004"
    Then I should see "Upcoming Installment Policy"

  # ═══════════════════════════════════════════════════════════════════════════
  # ACTIVE POLICIES SECTION
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Active Policies section is visible on show page
    Given a full individual customer exists with mobile "9601015001"
    When I visit the customer show page for mobile "9601015001"
    Then I should see "Active Policies"

  Scenario: Active Policies section has Add Policy button
    Given a full individual customer exists with mobile "9601015002"
    When I visit the customer show page for mobile "9601015002"
    Then I should see "Add Policy"

  Scenario: Customer with active health policy shows it in Active Policies section
    Given a customer with an active health insurance policy exists with mobile "9601015003"
    When I visit the customer show page for mobile "9601015003"
    And I expand the customer section "Active Policies"
    Then I should see the active policy company name

  Scenario: Customer without active policies shows zero count in Active Policies header
    Given a full individual customer exists with mobile "9601015004"
    When I visit the customer show page for mobile "9601015004"
    Then I should see customer active policies count as zero

  # ═══════════════════════════════════════════════════════════════════════════
  # ADDITIONAL INFORMATION SECTION
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Additional Information section header is visible
    Given a full individual customer exists with mobile "9601016001"
    When I visit the customer show page for mobile "9601016001"
    Then I should see "Additional Information"

  Scenario: Expanding Additional Information shows PAN number when present
    Given a full individual customer with PAN "ABCDE1234F" and mobile "9601016002"
    When I visit the customer show page for mobile "9601016002"
    And I expand the customer section "Additional Information"
    Then I should see "ABCDE1234F"

  Scenario: Expanding Additional Information shows GST number for corporate customer
    Given a corporate customer with GST "27AAPFU0939F1ZV" and mobile "9601016003"
    When I visit the customer show page for mobile "9601016003"
    And I expand the customer section "Additional Information"
    Then I should see "27AAPFU0939F1ZV"

  Scenario: Expanding Additional Information shows notes when present
    Given a full individual customer with notes "Special client notes" and mobile "9601016004"
    When I visit the customer show page for mobile "9601016004"
    And I expand the customer section "Additional Information"
    Then I should see "Special client notes"

  # ═══════════════════════════════════════════════════════════════════════════
  # ASSOCIATED LEADS SECTION
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Associated Leads section header is visible
    Given a full individual customer exists with mobile "9601017001"
    When I visit the customer show page for mobile "9601017001"
    Then I should see "Associated Leads"

  Scenario: Customer with associated lead shows lead in the section
    Given a customer with an associated lead exists with mobile "9601017002"
    When I visit the customer show page for mobile "9601017002"
    And I expand the customer section "Associated Leads"
    Then I should see "Lead ID"

  Scenario: Customer without leads shows empty state in Associated Leads
    Given a full individual customer exists with mobile "9601017003"
    When I visit the customer show page for mobile "9601017003"
    And I expand the customer section "Associated Leads"
    Then I should see "No Leads Found"

  Scenario: Associated lead shows product category
    Given a customer with an associated lead exists with mobile "9601017004"
    When I visit the customer show page for mobile "9601017004"
    And I expand the customer section "Associated Leads"
    Then I should see associated lead product category

  Scenario: Associated lead shows stage badge
    Given a customer with an associated lead exists with mobile "9601017005"
    When I visit the customer show page for mobile "9601017005"
    And I expand the customer section "Associated Leads"
    Then I should see associated lead stage

  # ═══════════════════════════════════════════════════════════════════════════
  # CORPORATE CUSTOMER SECTIONS
  # ═══════════════════════════════════════════════════════════════════════════

  Scenario: Corporate customer show page displays company name in header
    Given a corporate customer exists with mobile "9601018001"
    When I visit the customer show page for mobile "9601018001"
    Then I should see the corporate customer company name

  Scenario: Corporate customer show page has Corporate Members section
    Given a corporate customer exists with mobile "9601018002"
    When I visit the customer show page for mobile "9601018002"
    Then I should see "Corporate Members"

  Scenario: Corporate customer Basic Information section is visible
    Given a corporate customer exists with mobile "9601018003"
    When I visit the customer show page for mobile "9601018003"
    Then I should see "Basic Information"
