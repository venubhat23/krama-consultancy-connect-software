module InsuranceCompanyHelper
  # List of insurance companies with their types
  INSURANCE_COMPANIES = {
    # Life Insurance Companies
    "LIC (Life Insurance Corporation of India)" => "LIFE",
    "HDFC Life Insurance" => "LIFE",
    "ICICI Prudential Life Insurance" => "LIFE",
    "SBI Life Insurance" => "LIFE",
    "Max Life Insurance" => "LIFE",
    "Bajaj Allianz Life Insurance" => "LIFE",
    "Kotak Mahindra Life Insurance" => "LIFE",
    "Tata AIA Life Insurance" => "LIFE",
    "PNB MetLife Insurance" => "LIFE",
    "Aditya Birla Sun Life Insurance" => "LIFE",
    "Exide Life Insurance" => "LIFE",
    "Canara HSBC Life Insurance" => "LIFE",
    "Aegon Life Insurance" => "LIFE",
    "Pramerica Life Insurance" => "LIFE",
    "Sahara Life Insurance" => "LIFE",
    "Shriram Life Insurance" => "LIFE",
    "Bharti AXA Life Insurance" => "LIFE",
    "Future Generali Life Insurance" => "LIFE",
    "IDBI Federal Life Insurance" => "LIFE",
    "Edelweiss Tokio Life Insurance" => "LIFE",
    "Star Union Dai-ichi Life Insurance" => "LIFE",
    "IndiaFirst Life Insurance" => "LIFE",
    "Ageas Federal Life Insurance" => "LIFE",

    # Health Insurance Companies
    "Star Health and Allied Insurance" => "HEALTH",
    "Care Health Insurance" => "HEALTH",
    "Aditya Birla Health Insurance" => "HEALTH",
    "Manipal Cigna Health Insurance" => "HEALTH",
    "Niva Bupa Health Insurance" => "HEALTH",
    "Max Bupa Health Insurance" => "HEALTH",
    "ManipalCigna ProHealth Insurance" => "HEALTH",

    # General/Motor Insurance Companies
    "Acko General Insurance" => "GENERAL",
    "Bajaj Allianz General Insurance" => "GENERAL",
    "HDFC ERGO General Insurance" => "GENERAL",
    "ICICI Lombard General Insurance" => "GENERAL",
    "IFFCO Tokio General Insurance" => "GENERAL",
    "National Insurance Company" => "GENERAL",
    "The New India Assurance" => "GENERAL",
    "Oriental Insurance Company" => "GENERAL",
    "United India Insurance" => "GENERAL",
    "Universal Sompo General Insurance" => "GENERAL",
    "Cholamandalam MS General Insurance" => "GENERAL",
    "Liberty General Insurance" => "GENERAL",
    "Reliance General Insurance" => "GENERAL",
    "Royal Sundaram General Insurance" => "GENERAL",
    "Shriram General Insurance" => "GENERAL",
    "Tata AIG General Insurance" => "GENERAL",
    "Bharti AXA General Insurance" => "GENERAL",
    "Future Generali India Insurance" => "GENERAL",
    "Go Digit General Insurance" => "GENERAL",
    "Kotak Mahindra General Insurance" => "GENERAL",
    "Magma HDI General Insurance" => "GENERAL",
    "Raheja QBE General Insurance" => "GENERAL",
    "SBI General Insurance" => "GENERAL",
    "Zuno General Insurance" => "GENERAL"
  }.freeze

  # Get all insurance companies
  def insurance_companies_list
    INSURANCE_COMPANIES.keys
  end

  # Get life insurance companies only
  def life_insurance_companies
    INSURANCE_COMPANIES.select { |name, type| type == "LIFE" }.keys
  end

  # Get health insurance companies only
  def health_insurance_companies
    INSURANCE_COMPANIES.select { |name, type| type == "HEALTH" }.keys
  end

  # Get general insurance companies only (for motor insurance)
  def general_insurance_companies
    INSURANCE_COMPANIES.select { |name, type| type == "GENERAL" }.keys
  end

  # Alias for motor insurance
  def motor_insurance_companies
    general_insurance_companies
  end

  # Get options for select dropdown
  def insurance_company_options
    INSURANCE_COMPANIES.map { |name, type| ["#{name} (#{type})", name] }
  end

  # Get life insurance options for select dropdown
  def life_insurance_options
    life_insurance_companies.map { |name| [name, name] }
  end

  # Get health insurance options for select dropdown
  def health_insurance_options
    health_insurance_companies.map { |name| [name, name] }
  end

  # Get general insurance options for select dropdown
  def general_insurance_options
    general_insurance_companies.map { |name| [name, name] }
  end

  # Get motor insurance options (alias for general)
  def motor_insurance_options
    general_insurance_options
  end

  # Get company type by name
  def insurance_company_type(name)
    INSURANCE_COMPANIES[name]
  end

  # Check if company is health insurance
  def health_insurance?(name)
    insurance_company_type(name) == "HEALTH"
  end

  # Check if company is general insurance
  def general_insurance?(name)
    insurance_company_type(name) == "GENERAL"
  end
end