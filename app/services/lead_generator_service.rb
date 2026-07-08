class LeadGeneratorService
  def self.create_lead_for_insurance(insurance)
    # Skip if lead already exists (both lead_id is present AND the lead record exists)
    return if insurance.lead_id.present? && Lead.exists?(lead_id: insurance.lead_id)

    product_type = determine_product_type(insurance)
    customer = insurance.customer

    # Check for existing lead with same contact number and product type
    existing_lead = Lead.find_by(
      contact_number: customer.mobile,
      product_subcategory: product_type
    )

    if existing_lead
      # Check if the lead_id is already used by another insurance record of the same type
      existing_insurance = insurance.class.find_by(lead_id: existing_lead.lead_id)

      if existing_insurance && existing_insurance.id != insurance.id
        # Lead ID already used by another insurance, create a new lead instead
        Rails.logger.warn "Lead ID #{existing_lead.lead_id} already used by #{insurance.class.name} #{existing_insurance.id}, creating new lead"
      else
        # Safe to use existing lead
        existing_lead.update!(
          current_stage: 'converted',
          converted_customer_id: customer.id,
          policy_created_id: insurance.id,
          stage_updated_at: Time.current,
          notes: existing_lead.notes + "\n\nUpdated: Policy created - #{insurance.policy_number} on #{Date.current}"
        )

        # Update the insurance with existing lead_id
        insurance.update_column(:lead_id, existing_lead.lead_id)

        Rails.logger.info "Updated existing lead #{existing_lead.lead_id} for insurance #{insurance.id}"
        return existing_lead
      end
    end

    # Generate a unique lead ID for new lead
    generated_lead_id = LeadIdGeneratorService.generate_for_policy(
      insurance.customer,
      insurance.class.name
    )

    # Set additional lead data based on customer type and product
    lead_data = build_lead_data_for_insurance(insurance, product_type, generated_lead_id)

    # Skip email if it would cause uniqueness conflict
    if lead_data[:email].present?
      existing_email_lead = Lead.where(
        email: lead_data[:email],
        product_subcategory: product_type
      ).where.not(lead_id: generated_lead_id).first

      if existing_email_lead
        Rails.logger.warn "Email #{lead_data[:email]} already exists for #{product_type}, skipping email for lead #{generated_lead_id}"
        lead_data.delete(:email)
      end
    end

    lead = Lead.create!(lead_data)

    # Update the insurance with the generated lead_id
    insurance.update_column(:lead_id, generated_lead_id)

    Rails.logger.info "Created new lead #{generated_lead_id} for insurance #{insurance.id}"
    lead
  rescue StandardError => e
    Rails.logger.error "Failed to create lead for #{insurance.class.name} #{insurance.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    nil
  end

  def self.build_lead_data_for_insurance(insurance, product_type, lead_id)
    customer = insurance.customer

    base_data = {
      lead_id: lead_id,
      name: customer.display_name,
      contact_number: customer.mobile,
      email: customer.email,
      product_category: 'insurance',
      product_subcategory: product_type,
      current_stage: 'converted',
      lead_source: determine_lead_source(insurance),
      customer_type: customer.customer_type,
      converted_customer_id: customer.id,
      policy_created_id: insurance.id,
      stage_updated_at: Time.current,
      created_date: insurance.policy_booking_date || Date.current,
      referred_by: determine_referred_by(insurance),
      notes: "Auto-generated lead from #{insurance.class.name.underscore.humanize.downcase} policy creation. Policy Number: #{insurance.policy_number}",
      is_direct: insurance.sub_agent_id.blank?,
      affiliate_id: insurance.sub_agent_id
    }

    # Add customer type specific data
    if customer.individual?
      base_data.merge!(
        first_name: sanitize_name(customer.first_name),
        middle_name: sanitize_name(customer.middle_name),
        last_name: sanitize_name(customer.last_name),
        gender: customer.gender,
        birth_date: customer.birth_date,
        marital_status: customer.marital_status,
        pan_no: customer.pan_no
      )
    else
      base_data.merge!(
        company_name: customer.company_name,
        gst_no: customer.gst_no,
        pan_no: customer.pan_no
      )
    end

    # Add address information if available
    if customer.address.present?
      base_data[:address] = customer.address
      base_data[:city] = customer.city
      base_data[:state] = customer.state
    end

    base_data
  end

  private

  def self.find_existing_lead_for_customer(customer)
    # Try to find an existing lead for this customer by contact number or email
    Lead.where(
      'contact_number = ? OR (email IS NOT NULL AND email = ?)',
      customer.mobile,
      customer.email
    ).first
  end

  def self.determine_product_type(insurance)
    case insurance.class.name
    when 'HealthInsurance' then 'health'
    when 'LifeInsurance' then 'life'
    when 'MotorInsurance' then 'motor'
    when 'OtherInsurance' then 'other'
    else 'other'
    end
  end

  def self.determine_lead_source(insurance)
    # Check if it's customer-added
    if insurance.respond_to?(:is_customer_added?) && insurance.is_customer_added?
      'online'
    elsif insurance.sub_agent_id.present?
      'agent_referral'
    else
      'offline'
    end
  end

  def self.determine_referred_by(insurance)
    if insurance.sub_agent_id.present?
      insurance.sub_agent&.display_name
    elsif insurance.respond_to?(:distributor_id) && insurance.distributor_id.present?
      insurance.distributor&.full_name
    else
      nil
    end
  end

  def self.sanitize_name(name)
    return nil if name.blank?

    # Remove numbers and special characters, keep only letters and spaces
    sanitized = name.gsub(/[^a-zA-Z\s]/, '').strip

    # If the name becomes empty after sanitization, use a placeholder
    sanitized.present? ? sanitized : 'Customer'
  end
end