class LeadIdGeneratorService
  def self.generate_for_customer(customer)
    # Extract first 3 characters of customer name
    customer_name_part = if customer.individual?
      customer.first_name.to_s.strip.upcase[0, 3].ljust(3, 'X')
    else
      customer.company_name.to_s.strip.upcase[0, 3].ljust(3, 'X')
    end

    # Extract last 3 characters of mobile number (remove +91 and formatting)
    clean_mobile = customer.mobile.to_s.gsub(/[\s\-\(\)\+]/, '').gsub(/^91/, '')
    mobile_part = clean_mobile[-3, 3] || '000'

    # Extract first 3 characters of date of birth (DDMMYY format)
    dob_part = if customer.birth_date.present?
      customer.birth_date.strftime('%d%m%y')[0, 3]
    else
      Date.current.strftime('%d%m%y')[0, 3]
    end

    # Construct base lead ID
    base_lead_id = "CUSLEAD-#{customer_name_part}-#{mobile_part}-#{dob_part}"

    # Ensure uniqueness by checking against existing lead_ids in various models
    ensure_uniqueness(base_lead_id)
  end

  def self.generate_for_policy(customer, policy_type)
    base_lead_id = generate_for_customer(customer)

    # Add policy type suffix
    policy_suffix = case policy_type.to_s.downcase
                   when 'health', 'healthinsurance'
                     'HLT'
                   when 'life', 'lifeinsurance'
                     'LIF'
                   when 'motor', 'motorinsurance'
                     'MTR'
                   else
                     'OTH'
                   end

    policy_lead_id = "#{base_lead_id}-#{policy_suffix}"

    # Ensure uniqueness for policy-specific lead ID
    ensure_uniqueness(policy_lead_id)
  end

  private

  def self.ensure_uniqueness(base_lead_id)
    lead_id = base_lead_id
    counter = 1

    # Check against all models that use lead_id
    while lead_id_exists?(lead_id)
      lead_id = "#{base_lead_id}-#{counter.to_s.rjust(2, '0')}"
      counter += 1

      # Safety check to prevent infinite loop
      break if counter > 999
    end

    lead_id
  end

  def self.lead_id_exists?(lead_id)
    # Check in Lead model
    return true if Lead.exists?(lead_id: lead_id)

    # Check in Customer model
    return true if Customer.exists?(lead_id: lead_id)

    # Check in insurance models
    return true if HealthInsurance.exists?(lead_id: lead_id)
    return true if LifeInsurance.exists?(lead_id: lead_id)
    return true if MotorInsurance.exists?(lead_id: lead_id)

    # Check OtherInsurance if it exists and has lead_id column
    if defined?(OtherInsurance) && OtherInsurance.column_names.include?('lead_id')
      return true if OtherInsurance.exists?(lead_id: lead_id)
    end

    # Check in CommissionPayout if it has lead_id field
    return true if CommissionPayout.column_names.include?('lead_id') && CommissionPayout.exists?(lead_id: lead_id)

    false
  end
end