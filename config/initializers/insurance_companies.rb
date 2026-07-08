# Insurance Companies Constants
INSURANCE_COMPANIES = [
  { name: "Acko General Insurance Limited", type: "GENERAL" },
  { name: "Aditya Birla Health Insurance Co Ltd", type: "HEALTH" },
  { name: "Aditya Birla Health Insurance", type: "GENERAL" },
  { name: "Agriculture Insurance Company of India Ltd", type: "GENERAL" },
  { name: "Bajaj Allianz General Insurance Company Limited", type: "GENERAL" },
  { name: "Care Health Insurance Ltd", type: "HEALTH" },
  { name: "Care Health Insurance – General", type: "GENERAL" },
  { name: "Cholamandalam MS General Insurance Co Ltd", type: "GENERAL" },
  { name: "ECGC Limited", type: "GENERAL" },
  { name: "Generalli Central Insurance", type: "GENERAL" },
  { name: "Go Digit General Insurance", type: "GENERAL" },
  { name: "HDFC ERGO General Insurance Co Ltd", type: "GENERAL" },
  { name: "ICICI Prudential Life Insurance Co Ltd", type: "GENERAL" },
  { name: "IFFCO TOKIO General Insurance Co Ltd", type: "GENERAL" },
  { name: "Kotak Mahindra General Insurance Company Limited", type: "GENERAL" },
  { name: "Kshema General Insurance Limited", type: "GENERAL" },
  { name: "Liberty General Insurance Ltd", type: "GENERAL" },
  { name: "Manipal Cigna Health Insurance Company Limited", type: "HEALTH" },
  { name: "Manipal Cigna Health Insurance Company Limited", type: "GENERAL" },
  { name: "National Insurance Co Ltd", type: "GENERAL" },
  { name: "Navi General Insurance Limited", type: "GENERAL" },
  { name: "Niva Bupa Health Insurance Co Ltd", type: "HEALTH" },
  { name: "Oriental Insurance Company Limited", type: "GENERAL" },
  { name: "Raheja QBE General Insurance Co Ltd", type: "GENERAL" },
  { name: "Reliance General Insurance Co Ltd", type: "GENERAL" },
  { name: "Royal Sundaram General Insurance Co Ltd", type: "GENERAL" },
  { name: "Shriram General Insurance Company Limited", type: "GENERAL" },
  { name: "Star Health Allied Insurance Co Ltd", type: "HEALTH" },
  { name: "Star Health Allied Insurance Co Ltd", type: "GENERAL" },
  { name: "Tata AIG General Insurance Co Ltd", type: "GENERAL" },
  { name: "The New India Assurance Co Ltd", type: "GENERAL" },
  { name: "United India Insurance Company Limited", type: "GENERAL" },
  { name: "Universal Sompo General Insurance Co Ltd", type: "GENERAL" },
  { name: "Zuno General Insurance Ltd", type: "GENERAL" }
].freeze

# Helper methods for filtering insurance companies
module InsuranceCompanyHelper
  def self.all_companies
    INSURANCE_COMPANIES
  end

  def self.health_companies
    INSURANCE_COMPANIES.select { |company| company[:type] == "HEALTH" }
  end

  def self.general_companies
    INSURANCE_COMPANIES.select { |company| company[:type] == "GENERAL" }
  end

  def self.company_names
    INSURANCE_COMPANIES.map { |company| company[:name] }.uniq
  end

  def self.company_options_for_select
    INSURANCE_COMPANIES.map { |company| ["#{company[:name]} (#{company[:type]})", company[:name]] }
  end
end