module InsuranceCompanyMethods
  extend ActiveSupport::Concern
  include InsuranceCompanyConstants

  private

  # Get all insurance companies from InsuranceCompanyConstants
  def insurance_companies_list
    self.class.insurance_company_names
  end

  # Get health insurance companies only
  def health_insurance_companies
    self.class.health_insurance_companies.map { |company| company[:name] }
  end

  # Get life insurance companies only
  def life_insurance_companies
    self.class.life_insurance_companies.map { |company| company[:name] }
  end

  # Get motor insurance companies only
  def motor_insurance_companies
    self.class.general_insurance_companies.select { |company|
      company[:name].match?(/(Motor|General|ERGO|Digit|Allianz|IFFCO|Cholamandalam|Raheja|Sundaram)/i)
    }.map { |company| company[:name] }
  end

  # Get general insurance companies only
  def general_insurance_companies
    self.class.general_insurance_companies.map { |company| company[:name] }
  end

  # Get companies by insurance type
  def companies_by_type(insurance_type)
    case insurance_type.to_s.downcase
    when 'health'
      health_insurance_companies
    when 'life'
      life_insurance_companies
    when 'motor'
      motor_insurance_companies
    when 'general'
      general_insurance_companies
    else
      insurance_companies_list
    end
  end

  # Get options for select dropdown
  def insurance_company_options
    self.class.insurance_company_options
  end

  # Get health insurance options for select dropdown
  def health_insurance_options
    health_insurance_companies.map { |name| [name, name] }
  end

  # Get life insurance options for select dropdown
  def life_insurance_options
    life_insurance_companies.map { |name| [name, name] }
  end

  # Get motor insurance options for select dropdown
  def motor_insurance_options
    motor_insurance_companies.map { |name| [name, name] }
  end

  # Get general insurance options for select dropdown
  def general_insurance_options
    general_insurance_companies.map { |name| [name, name] }
  end

  # Get company type by name
  def insurance_company_type(name)
    self.class.insurance_company_type(name)
  end

  # Check if company is health insurance
  def health_insurance?(name)
    insurance_company_type(name) == "HEALTH"
  end

  # Check if company is life insurance
  def life_insurance?(name)
    insurance_company_type(name) == "LIFE"
  end

  # Check if company is motor insurance
  def motor_insurance?(name)
    insurance_company_type(name) == "MOTOR"
  end

  # Check if company is general insurance
  def general_insurance?(name)
    insurance_company_type(name) == "GENERAL"
  end
end