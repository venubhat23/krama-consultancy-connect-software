module InsuranceCompanyConstants
  extend ActiveSupport::Concern

  # Insurance company list with types
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
    { name: "ICICI Prudential Life Insurance Co Ltd", type: "LIFE" },
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
    { name: "Zuno General Insurance Ltd", type: "GENERAL" },

    # Life Insurance Companies
    { name: "SBI Life Insurance Co Ltd", type: "LIFE" },
    { name: "LIC India", type: "LIFE" },
    { name: "LIC of India", type: "LIFE" },
    { name: "HDFC Standard Life Insurance Co Ltd", type: "LIFE" },
    { name: "Max Life Insurance Co Ltd", type: "LIFE" },
    { name: "Bajaj Allianz Life Insurance Co Ltd", type: "LIFE" },
    { name: "Reliance Nippon Life Insurance Co Ltd", type: "LIFE" },
    { name: "Birla Sun Life Insurance Co Ltd", type: "LIFE" },
    { name: "Tata AIA Life Insurance Co Ltd", type: "LIFE" },
    { name: "Kotak Mahindra Old Mutual Life Insurance Ltd", type: "LIFE" },
    { name: "Aviva Life Insurance Co India Ltd", type: "LIFE" },
    { name: "Bharti AXA Life Insurance Co Ltd", type: "LIFE" },
    { name: "Canara HSBC Oriental Bank of Commerce Life Insurance Co Ltd", type: "LIFE" },
    { name: "Edelweiss Tokio Life Insurance Co Ltd", type: "LIFE" },
    { name: "Exide Life Insurance Co Ltd", type: "LIFE" },
    { name: "Future Generali India Life Insurance Co Ltd", type: "LIFE" },
    { name: "IDBI Federal Life Insurance Co Ltd", type: "LIFE" },
    { name: "IndiaFirst Life Insurance Co Ltd", type: "LIFE" },
    { name: "PNB MetLife India Insurance Co Ltd", type: "LIFE" },
    { name: "Sahara India Life Insurance Co Ltd", type: "LIFE" },
    { name: "Shriram Life Insurance Co Ltd", type: "LIFE" },
    { name: "Star Union Dai-ichi Life Insurance Co Ltd", type: "LIFE" }
  ].freeze

  class_methods do
    def insurance_companies
      INSURANCE_COMPANIES
    end

    def health_insurance_companies
      INSURANCE_COMPANIES.select { |company| company[:type] == "HEALTH" }
    end

    def general_insurance_companies
      INSURANCE_COMPANIES.select { |company| company[:type] == "GENERAL" }
    end

    def life_insurance_companies
      INSURANCE_COMPANIES.select { |company| company[:type] == "LIFE" }
    end

    def insurance_company_names
      INSURANCE_COMPANIES.map { |company| company[:name] }.uniq
    end

    def insurance_company_options
      INSURANCE_COMPANIES.map { |company|
        ["#{company[:name]} (#{company[:type]})", company[:name]]
      }
    end

    def find_insurance_company_by_name(name)
      INSURANCE_COMPANIES.find { |company| company[:name] == name }
    end

    def insurance_company_type(name)
      company = find_insurance_company_by_name(name)
      company ? company[:type] : nil
    end
  end
end