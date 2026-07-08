class Api::V1::Mobile::AgentController < Api::V1::Mobile::BaseController
  include InsuranceCompanyConstants
  before_action :authenticate_agent!, except: [:insurance_companies, :motor_insurance_companies]
  attr_reader :current_user

  # GET /api/v1/mobile/agent/dashboard
  def dashboard
    agent = current_user

    # Get dashboard statistics
    stats = get_dashboard_statistics(agent)

    render json: {
      success: true,
      data: {
        agent_info: {
          name: agent.full_name,
          email: agent.email,
          mobile: agent.mobile,
          role: agent.role&.name || 'sub_agent'
        },
        statistics: stats,
        recent_activities: get_recent_activities(agent),
        # Gross commission earned (before TDS deduction)
        commission_earned: stats[:commission_earned].to_f.round(2),
        commission_earned_formatted: format_indian_amount(stats[:commission_earned]),
        customers_count: stats[:customers_count].to_i,
        policies_count: stats[:policies_count].to_i
      }
    }
  end

  # GET /api/v1/mobile/agent/customers
  def customers
    agent = current_user
    page = params[:page] || 1
    per_page = params[:per_page] || 10
    filter = params[:filter] # 'all', 'agent_added', 'system_added'

    # Check if current user is admin
    customers = if is_admin?(agent)
                  Customer.all
                elsif is_sub_agent?(agent)
                  # For sub_agents, show all customers assigned to them (matching dashboard logic)
                  if agent.is_a?(SubAgent)
                    Customer.where(sub_agent_id: agent.id)
                  else
                    # For User with sub_agent type, find matching SubAgent
                    sub_agent = SubAgent.find_by(email: agent.email)
                    if sub_agent
                      Customer.where(sub_agent_id: sub_agent.id)
                    else
                      Customer.where(sub_agent_id: agent.id)
                    end
                  end
                else
                  # For regular agents, show customers from their policies only
                  _, _, _, agent_customer_ids = get_agent_policies(agent)
                  Customer.where(id: agent_customer_ids)
                end

    # Apply filter
    case filter
    when 'agent_added'
      customers = customers.where("added_by LIKE ?", "%agent_mobile_api_%")
    when 'system_added'
      customers = customers.where("added_by IS NULL OR added_by NOT LIKE ?", "%agent_mobile_api_%")
    # 'all' or nil shows all customers
    end

    customers = customers.includes(:documents, profile_image_attachment: :blob).active.page(page).per(per_page)

    # Preload users by email/mobile to fetch original_password without N+1
    customer_emails  = customers.map(&:email).compact
    customer_mobiles = customers.map(&:mobile).compact
    users_by_email  = User.where(email: customer_emails).index_by(&:email)
    users_by_mobile = User.where(mobile: customer_mobiles).index_by(&:mobile)

    # Preload commission data
    payout_to_value = if is_sub_agent?(current_user) || is_affiliate?(current_user)
                        'affiliate'
                      else
                        'agent'
                      end
    commission_payouts = CommissionPayout.where(payout_to: payout_to_value).index_by { |cp| "#{cp.policy_type}:#{cp.policy_id}" }

    customers_data = customers.map do |customer|
      # Format document data
      attached_documents = customer.documents.map do |doc|
        download_url = if doc.file.attached?
                        begin
                          Rails.application.routes.url_helpers.rails_blob_url(doc.file, host: 'dr-wise-ag.onrender.com', protocol: 'https')
                        rescue
                          nil
                        end
                      else
                        nil
                      end

        {
          document: doc.document_type,
          url: download_url
        }
      end

      # Include profile image if attached
      profile_image_url = if customer.profile_image.attached?
                           begin
                             Rails.application.routes.url_helpers.rails_blob_url(customer.profile_image, host: 'dr-wise-ag.onrender.com', protocol: 'https')
                           rescue
                             nil
                           end
                         else
                           nil
                         end

      {
        id: customer.id,
        name: customer.display_name,
        mobile: customer.mobile,
        email: customer.email,
        password: (users_by_email[customer.email] || users_by_mobile[customer.mobile])&.original_password,
        customer_type: customer.customer_type,
        status: customer.active? ? 'Active' : 'Inactive',
        policies_count: get_customer_policies_count(customer),
        total_premium: format_indian_amount(get_customer_total_premium(customer)),
        added_by: customer.added_by || 'system',
        added_via: determine_add_source(customer.added_by),
        created_at: customer.created_at,
        profile_image: profile_image_url,
        attached_documents: attached_documents,
        policies: get_customer_policies_with_documents(customer, commission_payouts)
      }
    end

    # Get statistics for different types
    stats = get_customer_statistics(agent)

    render json: {
      success: true,
      data: {
        customers: customers_data,
        statistics: stats,
        pagination: {
          current_page: page.to_i,
          per_page: per_page.to_i,
          total_customers: customers.total_count,
          total_pages: customers.total_pages
        }
      }
    }
  end

  # POST /api/v1/mobile/agent/customers
  def add_customer
    customer_params = params.permit(
      :customer_type, :first_name, :last_name, :company_name, :email,
      :mobile, :gender, :birth_date, :address, :city, :state, :pincode,
      :pan_no, :gst_no, :occupation, :annual_income, :marital_status,
      :nominee_name, :nominee_relation, :nominee_date_of_birth,
      :image_url, :password, :password_confirmation, :file1, :file2,
      documents: [:document_type, :document_file]
    )

    # Validation: Check required fields
    validation_errors = []
    validation_errors << 'First name is required' if customer_params[:first_name].blank?
    validation_errors << 'Mobile number is required' if customer_params[:mobile].blank?
    validation_errors << 'Email is required' if customer_params[:email].blank?

    # Auto-generate password if not provided
    auto_generated_password = false
    if customer_params[:password].blank? && customer_params[:password_confirmation].blank?
      # Auto-generate a secure password
      generated_password = generate_secure_password
      customer_params[:password] = generated_password
      customer_params[:password_confirmation] = generated_password
      auto_generated_password = true
    end

    # Validate password match only if both are provided
    if customer_params[:password].present? && customer_params[:password_confirmation].present?
      if customer_params[:password] != customer_params[:password_confirmation]
        validation_errors << 'Password and password confirmation do not match'
      end
    elsif customer_params[:password].present? && customer_params[:password_confirmation].blank?
      validation_errors << 'Password confirmation is required when password is provided'
    elsif customer_params[:password].blank? && customer_params[:password_confirmation].present?
      validation_errors << 'Password is required when password confirmation is provided'
    end

    # Validate password strength
    if customer_params[:password].present?
      password = customer_params[:password]
      if password.length < 8
        validation_errors << 'Password must be at least 8 characters long'
      end
      unless password.match?(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
        validation_errors << 'Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character'
      end
    end

    # Validate phone number format
    if customer_params[:mobile].present?
      clean_phone = customer_params[:mobile].gsub(/\D/, '')
      unless clean_phone.match?(/^[6-9]\d{9}$/)
        validation_errors << 'Invalid phone number format. Must be a valid Indian mobile number'
      end
    end

    # Validate email format
    if customer_params[:email].present? && !customer_params[:email].match?(URI::MailTo::EMAIL_REGEXP)
      validation_errors << 'Invalid email format'
    end

    # Check for existing customer with same email or mobile
    existing_customer = nil
    if customer_params[:email].present?
      existing_customer = Customer.find_by(email: customer_params[:email])
    end
    if existing_customer.nil? && customer_params[:mobile].present?
      existing_customer = Customer.find_by(mobile: customer_params[:mobile])
    end

    # Check for existing user with same email
    existing_user = nil
    if customer_params[:email].present?
      existing_user = User.find_by(email: customer_params[:email])
    end
    if existing_user
      validation_errors << 'A user with this email already exists'
    end

    # If customer already exists, return error
    if existing_customer
      return render json: {
        status: false,
        message: 'Customer with this email or mobile already exists',
        error: 'duplicate_customer',
        data: {
          customer_id: existing_customer.id,
          name: existing_customer.display_name,
          email: existing_customer.email,
          mobile: existing_customer.mobile,
          customer_type: existing_customer.customer_type,
          gender: existing_customer.gender,
          birth_date: existing_customer.birth_date&.strftime('%Y-%m-%d'),
          address: existing_customer.address,
          city: existing_customer.city,
          state: existing_customer.state,
          pincode: existing_customer.pincode,
          pan_no: existing_customer.pan_no,
          occupation: existing_customer.occupation,
          annual_income: existing_customer.annual_income,
          marital_status: existing_customer.marital_status,
          added_by: existing_customer.added_by,
          created_at: existing_customer.created_at&.strftime('%Y-%m-%d %H:%M:%S')
        }
      }, status: :conflict
    end

    if validation_errors.any?
      return render json: {
        status: false,
        message: 'Validation failed',
        errors: validation_errors
      }, status: :unprocessable_entity
    end

    # Convert certain fields to lowercase and exclude password fields (they're for User creation only)
    normalized_params = customer_params.except(:file1, :file2, :documents, :image_url, :password, :password_confirmation)
    normalized_params[:gender] = normalized_params[:gender]&.downcase
    normalized_params[:marital_status] = normalized_params[:marital_status]&.downcase

    # Determine the affiliate/sub_agent_id based on current user
    affiliate_id = nil
    if current_user.is_a?(SubAgent)
      # If current user is a SubAgent, use their ID directly
      affiliate_id = current_user.id
    elsif current_user.is_a?(User)
      # If current user is a User (agent), try to find matching SubAgent by email
      matching_sub_agent = SubAgent.find_by(email: current_user.email)
      affiliate_id = matching_sub_agent&.id
    end

    customer = Customer.new(normalized_params.merge(
      status: true,
      added_by: "agent_mobile_api_#{current_user.id}", # Track agent who added customer
      sub_agent_id: affiliate_id # Set affiliate relationship
    ))

    if customer.save
      # Create user account for customer
      user_creation_info = create_user_for_customer(customer, customer_params[:password])

      # Handle file uploads (optional, don't fail if they don't work)
      file_info = begin
        handle_customer_file_uploads(customer, params[:file1], params[:file2])
      rescue => e
        Rails.logger.error "Error handling file uploads for customer #{customer.id}: #{e.message}"
        {
          file1: nil,
          file2: nil,
          upload_status: 'error',
          upload_errors: [e.message]
        }
      end

      # Handle documents array if present (optional, don't fail if they don't work)
      if params[:documents].present?
        begin
          handle_customer_documents(customer, params[:documents])
        rescue => e
          Rails.logger.error "Error handling documents for customer #{customer.id}: #{e.message}"
        end
      end

      response_data = {
        customer_id: customer.id,
        name: customer.display_name,
        email: customer.email,
        mobile: customer.mobile,
        customer_type: customer.customer_type,
        gender: customer.gender,
        birth_date: customer.birth_date&.strftime('%Y-%m-%d'),
        address: customer.address,
        city: customer.city,
        state: customer.state,
        pincode: customer.pincode,
        pan_no: customer.pan_no,
        occupation: customer.occupation,
        annual_income: customer.annual_income,
        marital_status: customer.marital_status,
        files: file_info,
        user_account: user_creation_info,
        added_by: customer.added_by,
        added_by_agent: {
          id: current_user.id,
          name: current_user.full_name,
          email: current_user.email
        },
        created_at: customer.created_at.strftime('%Y-%m-%d %H:%M:%S')
      }

      # Add password info if auto-generated
      if auto_generated_password
        response_data[:password_info] = {
          auto_generated: true,
          password: customer_params[:password],
          message: 'Password was auto-generated since none was provided'
        }
      else
        response_data[:password_info] = {
          auto_generated: false,
          message: 'Password provided by user'
        }
      end

      render json: {
        status: true,
        message: 'Customer created successfully',
        data: response_data
      }, status: :created
    else
      render json: {
        status: false,
        message: 'Failed to create customer',
        errors: customer.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/mobile/agent/policies
  def policies
    agent = current_user

    # If no pagination parameters provided, show all records
    # If pagination parameters are provided, use them
    page = params[:page]
    per_page = params[:per_page]

    # Determine if pagination is requested
    paginate_results = page.present? || per_page.present?

    # Set default values only if pagination is requested
    page = (page || 1).to_i if paginate_results
    per_page = (per_page || 10).to_i if paginate_results

    policy_type = params[:policy_type] # 'health', 'life', 'motor', 'other', or 'all'

    policies = []

    # Determine what payout_to value to look for based on user type
    # Sub-agents should see affiliate commission, not sub_agent commission
    payout_to_value = if is_sub_agent?(current_user) || is_affiliate?(current_user)
                        'affiliate'
                      else
                        'agent'
                      end

    # Preload commission data to avoid N+1 queries
    commission_payouts = CommissionPayout.where(payout_to: payout_to_value).index_by { |cp| "#{cp.policy_type}:#{cp.policy_id}" }

    # Get agent's policies using the helper method
    agent_health_policies, agent_life_policies, agent_motor_policies, _ = get_agent_policies(agent)

    # Get health insurance policies
    if policy_type.blank? || policy_type == 'health' || policy_type == 'all'
      health_policies = if is_admin?(agent)
                         HealthInsurance.all
                       else
                         agent_health_policies
                       end

      health_policies.includes(:customer, :health_insurance_documents, documents_attachments: :blob, policy_documents_attachments: :blob).each do |policy|
        policies << format_policy_data_with_commission(policy, 'Health', commission_payouts)
      end
    end

    # Get life insurance policies
    if policy_type.blank? || policy_type == 'life' || policy_type == 'all'
      life_policies = if is_admin?(agent)
                       LifeInsurance.all
                     else
                       agent_life_policies
                     end

      life_policies.includes(:customer, :life_insurance_documents).each do |policy|
        policies << format_policy_data_with_commission(policy, 'Life', commission_payouts)
      end
    end

    # Get motor insurance policies
    if policy_type.blank? || policy_type == 'motor' || policy_type == 'all'
      motor_policies = if is_admin?(agent)
                         MotorInsurance.all
                       else
                         agent_motor_policies
                       end

      motor_policies.includes(:customer, :motor_insurance_documents).each do |policy|
        policies << format_policy_data_with_commission(policy, 'Motor', commission_payouts)
      end
    end

    # Get other insurance policies
    if policy_type.blank? || policy_type == 'other' || policy_type == 'all'
      other_policies = if is_admin?(agent)
                         Policy.where(insurance_type: 'other')
                       else
                         Policy.where(insurance_type: 'other', user: agent)
                       end

      other_policies.includes(:customer, documents_attachments: :blob, policy_documents_attachments: :blob).each do |policy|
        policies << format_policy_data_with_commission(policy, 'Other', commission_payouts)
      end
    end

    # Sort by creation date (newest first)
    policies = policies.sort_by { |p| p[:created_at] }.reverse

    # Apply pagination only if requested
    total_policies = policies.count

    if paginate_results
      # Paginate manually when pagination parameters are provided
      start_index = (page.to_i - 1) * per_page.to_i
      end_index = start_index + per_page.to_i - 1
      paginated_policies = policies[start_index..end_index] || []

      render json: {
        success: true,
        data: {
          policies: paginated_policies,
          pagination: {
            current_page: page.to_i,
            per_page: per_page.to_i,
            total_policies: total_policies,
            total_pages: (total_policies.to_f / per_page.to_i).ceil
          }
        }
      }
    else
      # Return all policies without pagination when no pagination parameters are provided
      render json: {
        success: true,
        data: {
          policies: policies,
          total_policies: total_policies
        }
      }
    end
  end

  # POST /api/v1/mobile/agent/policies/health
  def add_health_policy
    # Updated parameter structure based on your specification
    policy_params = params.permit(
      :client_id, :policy_holder, :insurance_company_id,:insurance_company_name, :policy_type, :insurance_type,
      :plan_name, :policy_number, :policy_booking_date, :policy_start_date, :policy_end_date,
      :policy_term_years, :payment_mode, :sum_insured, :net_premium, :gst_percentage, :total_premium,
      :installment_autopay_start_date, :installment_autopay_end_date,
      family_members: [:full_name, :age, :relationship, :sum_insured],
      documents: [:document_type, :document_file]
    )

    # Validation: Check required fields
    validation_errors = []
    validation_errors << 'Client ID is required' if policy_params[:client_id].blank?
    validation_errors << 'Policy holder is required' if policy_params[:policy_holder].blank?
    validation_errors << 'Insurance company ID is required' if policy_params[:insurance_company_id].blank?
    validation_errors << 'Plan name is required' if policy_params[:plan_name].blank?
    validation_errors << 'Policy number is required' if policy_params[:policy_number].blank?
    validation_errors << 'Net premium is required' if policy_params[:net_premium].blank?

    if validation_errors.any?
      return render json: {
        status: false,
        message: 'Validation failed',
        errors: validation_errors
      }, status: :unprocessable_entity
    end

    # Find customer (client)
    customer = Customer.find_by(id: policy_params[:client_id])
    unless customer
      return render json: {
        status: false,
        message: 'Customer not found'
      }, status: :not_found
    end

    # Check if policy number already exists
    if HealthInsurance.exists?(policy_number: policy_params[:policy_number])
      return render json: {
        status: false,
        message: 'Validation failed',
        errors: {
          policy_number: ['has already been taken']
        }
      }, status: :unprocessable_entity
    end

    # Calculate total premium if not provided
    calculated_total_premium = if policy_params[:total_premium].present?
                                policy_params[:total_premium].to_f
                              else
                                net_premium = policy_params[:net_premium].to_f
                                gst_percentage = policy_params[:gst_percentage].to_f || 18.0
                                net_premium + (net_premium * gst_percentage / 100.0)
                              end

    # Create health insurance policy
    policy = HealthInsurance.new(
      customer_id: policy_params[:client_id],
      sub_agent_id: current_user.id, # Associate with the current agent
      policy_holder: policy_params[:policy_holder],
      insurance_company_name: policy_params[:insurance_company_name],
      policy_type: policy_params[:policy_type],
      insurance_type: policy_params[:insurance_type] || 'health',
      plan_name: policy_params[:plan_name],
      policy_number: policy_params[:policy_number],
      policy_booking_date: parse_date(policy_params[:policy_booking_date]) || Date.current,
      policy_start_date: parse_date(policy_params[:policy_start_date]),
      policy_end_date: parse_date(policy_params[:policy_end_date]),
      payment_mode: policy_params[:payment_mode],
      sum_insured: policy_params[:sum_insured],
      net_premium: policy_params[:net_premium],
      gst_percentage: policy_params[:gst_percentage] || 18.0,
      total_premium: calculated_total_premium,
      is_agent_added: true,
      is_admin_added: false
    )

    if policy.save
      # Handle family members
      if params[:family_members].present?
        params[:family_members].each do |member_data|
          create_family_member(policy, member_data)
        end
      end

      # Handle document uploads
      if params[:documents].present?
        handle_document_uploads(policy, params[:documents])
      end

      render json: {
        status: true,
        message: 'Health policy created successfully',
        data: {
          policy_id: policy.id,
          policy_number: policy.policy_number,
          client_name: customer.display_name,
          total_premium: policy.total_premium,
          created_at: policy.created_at.strftime('%Y-%m-%d %H:%M:%S')
        }
      }, status: :created
    else
      render json: {
        status: false,
        message: 'Validation failed',
        errors: policy.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/mobile/agent/policies/life
  def add_life_policy
    # Updated parameter structure based on the API documentation
    policy_params = params.permit(
      :client_id, :policy_holder, :insured_name, :insurance_company_id, :agency_code_id,
      :policy_type, :payment_mode, :policy_number, :policy_booking_date, :policy_start_date, :policy_end_date,
      :policy_term_years, :premium_payment_term_years, :plan_name, :sum_insured, :net_premium,
      :gst_percentage_year_1, :gst_percentage_year_2, :gst_percentage_year_3, :total_premium,
      :reference_by_name, :installment_autopay_start_date, :installment_autopay_end_date,
      nominees: [:nominee_name, :relationship, :age],
      bank_details: [:bank_name, :account_type, :account_number, :ifsc_code, :account_holder_name],
      documents: [:document_type, :document_file]
    )

    # Validation: Check required fields
    validation_errors = []
    validation_errors << 'Client ID is required' if policy_params[:client_id].blank?
    validation_errors << 'Policy holder is required' if policy_params[:policy_holder].blank?
    validation_errors << 'Insured name is required' if policy_params[:insured_name].blank?
    validation_errors << 'Insurance company ID is required' if policy_params[:insurance_company_id].blank?
    validation_errors << 'Policy number is required' if policy_params[:policy_number].blank?
    validation_errors << 'Policy start date is required' if policy_params[:policy_start_date].blank?
    validation_errors << 'Policy end date is required' if policy_params[:policy_end_date].blank?
    validation_errors << 'Policy term years is required' if policy_params[:policy_term_years].blank?
    validation_errors << 'Premium payment term years is required' if policy_params[:premium_payment_term_years].blank?
    validation_errors << 'Net premium is required' if policy_params[:net_premium].blank?
    # GST percentage is optional for life insurance

    if validation_errors.any?
      return render json: {
        status: false,
        message: 'Validation failed',
        errors: validation_errors
      }, status: :unprocessable_entity
    end

    # Find customer (client)
    customer = Customer.find_by(id: policy_params[:client_id])
    unless customer
      return render json: {
        status: false,
        message: 'Customer not found'
      }, status: :not_found
    end

    # Check if policy number already exists
    if LifeInsurance.exists?(policy_number: policy_params[:policy_number])
      return render json: {
        status: false,
        message: 'Validation failed',
        errors: {
          policy_number: ['already exists']
        }
      }, status: :unprocessable_entity
    end

    # Calculate total premium if not provided
    calculated_total_premium = if policy_params[:total_premium].present?
                                policy_params[:total_premium].to_f
                              else
                                net_premium = policy_params[:net_premium].to_f
                                gst_percentage = policy_params[:gst_percentage_year_1].to_f
                                net_premium + (net_premium * gst_percentage / 100.0)
                              end

    # Map policy type values
    mapped_policy_type = case policy_params[:policy_type]
                        when 'term', 'endowment', 'ulip'
                          'New'
                        else
                          'New'
                        end

    # Create life insurance policy with the correct field mappings
    policy = LifeInsurance.new(
      customer_id: policy_params[:client_id],
      sub_agent_id: current_user.id, # Associate with the current agent
      policy_holder: policy_params[:policy_holder],
      insured_name: policy_params[:insured_name],
      insurance_company_name: get_company_name_by_id(policy_params[:insurance_company_id]),
      distributor_id: Distributor.exists?(1) ? 1 : nil,
      agency_code_id: AgencyCode.exists?(policy_params[:agency_code_id]) ? policy_params[:agency_code_id] : nil,
      policy_type: mapped_policy_type,
      payment_mode: policy_params[:payment_mode]&.capitalize || 'Yearly',
      policy_number: policy_params[:policy_number],
      policy_booking_date: parse_date(policy_params[:policy_booking_date]) || Date.current,
      policy_start_date: parse_date(policy_params[:policy_start_date]),
      policy_end_date: parse_date(policy_params[:policy_end_date]),
      policy_term: policy_params[:policy_term_years],
      premium_payment_term: policy_params[:premium_payment_term_years],
      plan_name: policy_params[:plan_name],
      sum_insured: policy_params[:sum_insured],
      net_premium: policy_params[:net_premium],
      first_year_gst_percentage: policy_params[:gst_percentage_year_1],
      second_year_gst_percentage: policy_params[:gst_percentage_year_2],
      third_year_gst_percentage: policy_params[:gst_percentage_year_3],
      total_premium: calculated_total_premium,
      reference_by_name: policy_params[:reference_by_name],
      installment_autopay_start_date: parse_date(policy_params[:installment_autopay_start_date]),
      installment_autopay_end_date: parse_date(policy_params[:installment_autopay_end_date]),
      is_agent_added: true,
      is_customer_added: false,
      is_admin_added: false
    )

    if policy.save
      # Handle nominees
      if params[:nominees].present?
        params[:nominees].each do |nominee_data|
          # Validate nominee age (should be reasonable)
          if nominee_data[:age].present? && (nominee_data[:age].to_i < 0 || nominee_data[:age].to_i > 120)
            Rails.logger.warn "Invalid nominee age: #{nominee_data[:age]}, setting to nil"
            nominee_data[:age] = nil
          end
          create_life_insurance_nominee(policy, nominee_data)
        end
      end

      # Handle bank details (only if they have actual data)
      if params[:bank_details].present?
        bank_data = params[:bank_details]
        # Only create bank details if at least one field has actual data
        if bank_data[:bank_name].present? || bank_data[:account_number].present? || bank_data[:ifsc_code].present?
          create_life_insurance_bank_details(policy, bank_data)
        end
      end

      # Handle document uploads
      if params[:documents].present?
        handle_life_insurance_document_uploads(policy, params[:documents])
      end

      render json: {
        status: true,
        message: 'Life policy created successfully',
        data: {
          policy_id: policy.id,
          policy_number: policy.policy_number,
          client_name: customer.display_name,
          total_premium: policy.total_premium,
          created_at: policy.created_at.strftime('%Y-%m-%d %H:%M:%S')
        }
      }, status: :created
    else
      render json: {
        status: false,
        message: 'Validation failed',
        errors: policy.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/mobile/agent/policies/motor
  def add_motor_policy
    policy_params = params.permit(
      :customer_id, :policy_holder, :plan_name, :policy_number,
      :insurance_company_name, :policy_type, :policy_start_date, :policy_end_date,
      :policy_booking_date, :sum_insured, :net_premium, :gst_percentage, :total_premium,
      :agent_commission_percentage, :commission_amount, :vehicle_type, :make, :model,
      :registration_number, :registration_date, :engine_number, :chassis_number, :mfy,
      :variant, :seating_capacity, :vehicle_idv, :zero_depreciation, :roadside_assistance,
      :ncb, :previous_policy_number, :payment_mode,
      documents: [:document_type, :document_file]
    )

    if policy_params[:customer_id].blank?
      return render json: {
        success: false,
        message: 'Customer ID is required'
      }, status: :unprocessable_entity
    end

    customer = Customer.find_by(id: policy_params[:customer_id])
    unless customer
      return render json: {
        success: false,
        message: 'Customer not found'
      }, status: :not_found
    end

    # Create motor insurance policy directly
    policy = MotorInsurance.new(
      customer_id: customer.id,
      sub_agent_id: current_user.id,
      policy_holder: policy_params[:policy_holder],
      plan_name: policy_params[:plan_name],
      insurance_company_name: policy_params[:insurance_company_name],
      policy_number: policy_params[:policy_number],
      policy_type: policy_params[:policy_type] == 'renewal' ? 'Renewal' : 'New',
      policy_start_date: parse_date(policy_params[:policy_start_date]),
      policy_end_date: parse_date(policy_params[:policy_end_date]),
      policy_booking_date: parse_date(policy_params[:policy_booking_date]) || Date.current,
      vehicle_type: 'New Vehicle', # Default based on model requirements
      class_of_vehicle: policy_params[:vehicle_type] || 'Private Car', # Use parameter or default
      insurance_type: 'Comprehensive', # Default
      registration_number: policy_params[:registration_number],
      registration_date: parse_date(policy_params[:registration_date]),
      make: policy_params[:make],
      model: policy_params[:model],
      mfy: policy_params[:mfy],
      variant: policy_params[:variant],
      seating_capacity: policy_params[:seating_capacity],
      engine_number: policy_params[:engine_number],
      chassis_number: policy_params[:chassis_number],
      vehicle_idv: policy_params[:vehicle_idv],
      sum_insured: policy_params[:sum_insured],
      net_premium: policy_params[:net_premium],
      gst_percentage: policy_params[:gst_percentage] || 18,
      total_premium: policy_params[:total_premium],
      tp_premium: 0, # Default for comprehensive
      main_agent_commission_percentage: policy_params[:agent_commission_percentage],
      zero_depreciation: policy_params[:zero_depreciation],
      roadside_assistance: policy_params[:roadside_assistance],
      ncb: policy_params[:ncb],
      previous_policy_number: policy_params[:previous_policy_number],
      payment_mode: policy_params[:payment_mode] || 'Annual',
      is_agent_added: true,
      is_customer_added: false,
      is_admin_added: false
    )

    if policy.save
      # Handle document uploads
      if params[:documents].present?
        handle_motor_insurance_document_uploads(policy, params[:documents])
      end

      render json: {
        success: true,
        message: 'Motor insurance policy added successfully',
        data: format_policy_data(policy, 'Motor')
      }
    else
      render json: {
        success: false,
        message: 'Failed to add motor insurance policy',
        errors: policy.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/mobile/agent/policies/other
  def add_other_policy
    policy_params = params.permit(
      :customer_id, :policy_holder, :plan_name, :policy_number,
      :insurance_company_name, :policy_type, :policy_start_date, :policy_end_date,
      :payment_mode, :sum_insured, :net_premium, :gst_percentage, :total_premium,
      :agent_commission_percentage, :commission_amount, :coverage_type, :description
    )

    if policy_params[:customer_id].blank?
      return render json: {
        success: false,
        message: 'Customer ID is required'
      }, status: :unprocessable_entity
    end

    customer = Customer.find_by(id: policy_params[:customer_id])
    unless customer
      return render json: {
        success: false,
        message: 'Customer not found'
      }, status: :not_found
    end

    # For Other insurance, we can use the Policy model with other type
    policy = Policy.new(
      customer: customer,
      user: current_user,
      insurance_company_id: 1, # Default, should be dynamic
      agency_broker_id: 1, # Default, should be dynamic
      policy_number: policy_params[:policy_number],
      plan_name: policy_params[:plan_name],
      insurance_type: 'other',
      policy_type: policy_params[:policy_type] == 'renewal' ? 'renewal' : 'new_policy',
      policy_start_date: policy_params[:policy_start_date],
      policy_end_date: policy_params[:policy_end_date],
      payment_mode: policy_params[:payment_mode] || 'yearly',
      sum_insured: policy_params[:sum_insured],
      net_premium: policy_params[:net_premium],
      gst_percentage: policy_params[:gst_percentage] || 18,
      total_premium: policy_params[:total_premium],
      agent_commission_percentage: policy_params[:agent_commission_percentage],
      commission_amount: policy_params[:commission_amount],
      status: true
    )

    if policy.save
      # Create other insurance specific data
      other_insurance = OtherInsurance.create!(
        policy: policy,
        coverage_type: policy_params[:coverage_type],
        description: policy_params[:description]
      )

      render json: {
        success: true,
        message: 'Other insurance policy added successfully',
        data: format_policy_data(policy, 'Other')
      }
    else
      render json: {
        success: false,
        message: 'Failed to add other insurance policy',
        errors: policy.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/mobile/agent/leads
  def add_lead
    # Updated parameter structure for leads
    lead_params = params.permit(
      :name, :contact_number, :email, :product_interest, :address, :city, :state,
      :referred_by, :current_stage, :created_date, :note, :call_disposition,
      :lead_source, :referral_amount, :transferred_amount, :priority
    )

    # Validation: Check required fields
    validation_errors = []
    validation_errors << 'Name is required' if lead_params[:name].blank?
    validation_errors << 'Contact number is required' if lead_params[:contact_number].blank?

    # Validate phone number format
    if lead_params[:contact_number].present?
      clean_phone = lead_params[:contact_number].gsub(/\D/, '')
      unless clean_phone.match?(/^[6-9]\d{9}$/) || lead_params[:contact_number].match?(/^\+91[6-9]\d{9}$/)
        validation_errors << 'Invalid phone number format. Must be a valid Indian mobile number'
      end
    end

    # Validate email format if provided
    if lead_params[:email].present? && !lead_params[:email].match?(URI::MailTo::EMAIL_REGEXP)
      validation_errors << 'Invalid email format'
    end

    # Check for existing leads with same contact number or email
    if lead_params[:contact_number].present?
      existing_lead = Lead.find_by(contact_number: lead_params[:contact_number])
      if existing_lead
        validation_errors << "A lead with contact number #{lead_params[:contact_number]} already exists (Lead ID: #{existing_lead.lead_id})"
      end
    end

    if lead_params[:email].present?
      existing_lead = Lead.find_by(email: lead_params[:email])
      if existing_lead
        validation_errors << "A lead with email #{lead_params[:email]} already exists (Lead ID: #{existing_lead.lead_id})"
      end
    end

    if validation_errors.any?
      return render json: {
        status: false,
        message: 'Validation failed',
        errors: validation_errors
      }, status: :unprocessable_entity
    end

    # Map product interest to category and subcategory
    product_interest = lead_params[:product_interest] || 'health'
    product_category = 'insurance'
    product_subcategory = case product_interest.downcase
                         when 'health' then 'health'
                         when 'life' then 'life'
                         when 'motor' then 'motor'
                         when 'home' then 'general'
                         when 'travel' then 'travel'
                         else 'other'
                         end

    # Split name into first_name and last_name for individual customers
    name_parts = lead_params[:name].to_s.strip.split(' ')
    first_name = name_parts.first || 'Customer'
    last_name = name_parts.length > 1 ? name_parts[1..-1].join(' ') : 'Name'

    # Determine if lead should be direct or affiliate-based
    is_direct_lead = true
    affiliate_id = nil

    # If the logged-in user is a SubAgent, set them as the affiliate
    if current_user.is_a?(SubAgent)
      is_direct_lead = false
      affiliate_id = current_user.id
    elsif current_user.is_a?(User) && current_user.user_type == 'agent'
      # For User agents, try to find matching SubAgent
      matching_sub_agent = SubAgent.find_by(email: current_user.email)
      if matching_sub_agent
        is_direct_lead = false
        affiliate_id = matching_sub_agent.id
      end
    end

    # Create lead with required fields and agent tracking
    lead = Lead.new(
      name: lead_params[:name],
      first_name: first_name,
      last_name: last_name,
      contact_number: lead_params[:contact_number],
      email: lead_params[:email],
      customer_type: 'individual', # Default to individual
      product_category: product_category,
      product_subcategory: product_subcategory,
      address: lead_params[:address],
      city: lead_params[:city],
      state: lead_params[:state],
      referred_by: lead_params[:referred_by],
      current_stage: lead_params[:current_stage] || 'lead_generated',
      created_date: parse_date(lead_params[:created_date]) || Date.current,
      notes: lead_params[:note],
      call_disposition: lead_params[:call_disposition],
      lead_source: lead_params[:lead_source] || 'agent_referral',
      referral_amount: lead_params[:referral_amount] || 0.0,
      transferred_amount: lead_params[:transferred_amount] || false,
      is_direct: is_direct_lead,
      affiliate_id: affiliate_id,
      stage_updated_at: Time.current
    )

    if lead.save
      render json: {
        status: true,
        message: 'Lead created successfully',
        data: {
          lead_id: lead.lead_id,
          id: lead.id,
          name: lead.display_name,
          contact_number: lead.contact_number,
          email: lead.email,
          product_interest: product_interest,
          product_category: lead.product_category,
          product_subcategory: lead.product_subcategory,
          customer_type: lead.customer_type,
          current_stage: lead.current_stage,
          lead_source: lead.lead_source,
          created_at: lead.created_at.strftime('%Y-%m-%d %H:%M:%S'),
          stage_progress: lead.stage_progress_percentage,
          can_advance: lead.can_advance?,
          next_stage: lead.next_stage,
          full_address: lead.full_address,
          referral_type: lead.referral_type,
          affiliate_info: affiliate_id ? {
            affiliate_id: affiliate_id,
            affiliate_name: lead.affiliate&.display_name,
            is_direct: lead.is_direct
          } : {
            is_direct: lead.is_direct,
            affiliate_id: nil
          },
          created_by: {
            agent_id: current_user.id,
            agent_name: current_user.respond_to?(:display_name) ? current_user.display_name : current_user.full_name,
            agent_type: current_user.class.name
          }
        }
      }, status: :created
    else
      render json: {
        status: false,
        message: 'Failed to create lead',
        errors: lead.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/mobile/agent/leads
  def leads
    page = params[:page] || 1
    per_page = params[:per_page] || 10
    stage_filter = params[:stage] # 'consultation', 'converted', etc.
    product_filter = params[:product] # 'health', 'life', etc.
    search = params[:search]

    # Base query - filter leads based on user type
    leads = Lead.includes(:converted_customer, :created_policy, :affiliate, :ambassador)

    # Filter leads based on user type
    agent = current_user
    if is_admin?(agent)
      # Admin can see all leads
      leads = leads.recent
    elsif is_sub_agent?(agent)
      # For sub_agents, show only leads created by them
      if agent.is_a?(SubAgent)
        leads = leads.where(affiliate_id: agent.id).recent
      else
        # For User with sub_agent type, find matching SubAgent
        sub_agent = SubAgent.find_by(email: agent.email)
        if sub_agent
          leads = leads.where(affiliate_id: sub_agent.id).recent
        else
          leads = leads.where(affiliate_id: agent.id).recent
        end
      end
    else
      # For regular agents, show leads they may have access to (direct leads for now)
      leads = leads.where(is_direct: true).recent
    end

    # Apply filters
    leads = leads.by_stage(stage_filter) if stage_filter.present?
    leads = leads.by_product(product_filter) if product_filter.present?

    # Apply search
    if search.present?
      leads = leads.search_leads(search)
    end

    # Paginate
    leads = leads.page(page).per(per_page)

    leads_data = leads.map do |lead|
      {
        id: lead.id,
        lead_id: lead.lead_id,
        name: lead.name,
        display_name: lead.display_name,
        first_name: lead.first_name,
        middle_name: lead.middle_name,
        last_name: lead.last_name,
        company_name: lead.company_name,
        contact_number: lead.contact_number,
        alternate_contact_number: lead.alternate_contact_number,
        email: lead.email,
        current_stage: lead.current_stage,
        stage_display_name: lead.stage_display_name,
        stage_description: lead.stage_description,
        stage_badge_class: lead.stage_badge_class,
        lead_source: lead.lead_source,
        source_badge_class: lead.source_badge_class,
        product_category: lead.product_category,
        product_subcategory: lead.product_subcategory,
        product_subcategory_display: lead.product_subcategory_display,
        product_badge_class: lead.product_badge_class,
        customer_type: lead.customer_type,
        gender: lead.gender,
        date_of_birth: lead.date_of_birth,
        age: lead.age,
        marital_status: lead.marital_status,
        occupation: lead.occupation,
        annual_income: lead.annual_income,
        business_job: lead.business_job,
        pan_no: lead.pan_no,
        gst_no: lead.gst_no,
        height: lead.height,
        weight: lead.weight,
        formatted_height: lead.formatted_height,
        address: lead.address,
        city: lead.city,
        state: lead.state,
        pincode: lead.pincode,
        full_address: lead.full_address,
        created_date: lead.created_date,
        formatted_created_date: lead.formatted_created_date,
        stage_updated_at: lead.stage_updated_at,
        notes: lead.notes,
        follow_up_date: lead.follow_up_date,
        follow_up_time: lead.follow_up_time,
        is_converted: lead.converted_customer_id.present?,
        converted_customer_id: lead.converted_customer_id,
        converted_customer_name: lead.converted_customer&.display_name,
        policy_created_id: lead.policy_created_id,
        is_direct: lead.is_direct,
        referral_type: lead.referral_type,
        affiliate_name: lead.affiliate_name,
        ambassador_name: lead.ambassador_name,
        stage_progress_percentage: lead.stage_progress_percentage,
        can_advance: lead.can_advance?,
        can_go_back: lead.can_go_back?,
        next_stage: lead.next_stage,
        previous_stage: lead.previous_stage,
        next_stage_options: lead.next_stage_options,
        can_convert_to_customer: lead.can_convert_to_customer?,
        can_create_policy: lead.can_create_policy?,
        locked_stage: lead.locked_stage?,
        is_branch_out: lead.is_branch_out?,
        disease_details: lead.disease_details,
        medicine_details: lead.medicine_details,
        doctor_details: lead.doctor_details,
        smoke_habbit: lead.smoke_habbit,
        alcohol_habbit: lead.alcohol_habbit,
        existing_policy_details: lead.existing_policy_details,
        branch_out_leads: lead.branch_out_leads.map { |bl|
          {
            id: bl.id,
            lead_id: bl.lead_id,
            name: bl.name,
            current_stage: bl.current_stage
          }
        },
        created_at: lead.created_at,
        updated_at: lead.updated_at
      }
    end

    # Get statistics filtered by user type
    stats = get_leads_statistics_for_user(agent)

    render json: {
      success: true,
      data: {
        leads: leads_data,
        statistics: stats,
        pagination: {
          current_page: page.to_i,
          per_page: per_page.to_i,
          total_leads: leads.total_count,
          total_pages: leads.total_pages
        }
      }
    }
  end

  # GET /api/v1/mobile/agent/form_data
  def form_data
    render json: {
      success: true,
      data: {
        clients: get_clients_dropdown,
        insurance_companies: get_insurance_companies_dropdown,
        payment_modes: ['monthly', 'quarterly', 'half_yearly', 'yearly', 'single'],
        policy_types: ['individual', 'family', 'group'],
        insurance_types: ['health', 'life', 'motor', 'other'],
        policy_holder_options: ['self', 'other'],
        relationships: ['self', 'spouse', 'child', 'father', 'mother', 'brother', 'sister'],
        document_types: ['policy_copy', 'proposal_form', 'medical_reports', 'id_proof', 'address_proof'],

        # Leads related dropdowns
        lead_stages: [
          { value: 'consultation', label: 'Consultation' },
          { value: 'one_on_one', label: 'One-on-One' },
          { value: 'converted', label: 'Converted' },
          { value: 'policy_created', label: 'Policy Created' },
          { value: 'referral_settled', label: 'Referral Settled' }
        ],
        lead_sources: [
          { value: 'online', label: 'Online' },
          { value: 'offline', label: 'Offline' },
          { value: 'agent_referral', label: 'Agent Referral' },
          { value: 'walk_in', label: 'Walk In' },
          { value: 'tele_calling', label: 'Tele Calling' },
          { value: 'campaign', label: 'Campaign' }
        ],
        product_interests: [
          { value: 'health', label: 'Health Insurance' },
          { value: 'life', label: 'Life Insurance' },
          { value: 'motor', label: 'Motor Insurance' },
          { value: 'home', label: 'Home Insurance' },
          { value: 'travel', label: 'Travel Insurance' },
          { value: 'other', label: 'Other Insurance' }
        ],
        priority_levels: [
          { value: 'high', label: 'High' },
          { value: 'medium', label: 'Medium' },
          { value: 'low', label: 'Low' }
        ],
        states: get_indian_states,

        customer_types: ['individual', 'corporate'],
        genders: ['Male', 'Female', 'Other'],
        marital_statuses: ['Single', 'Married', 'Divorced', 'Widowed'],
        vehicle_types: ['Two Wheeler', 'Four Wheeler', 'Commercial Vehicle'],
        coverage_types: ['Property', 'Travel', 'Personal Accident', 'Fire', 'Marine', 'Cyber Security', 'Other'],

        # Commission distribution filters
        commission_periods: [
          { value: 'all', label: 'All Time' },
          { value: 'this_month', label: 'This Month' },
          { value: 'last_month', label: 'Last Month' },
          { value: 'this_year', label: 'This Year' }
        ],
        commission_policy_types: [
          { value: 'all', label: 'All Policy Types' },
          { value: 'health', label: 'Health Insurance' },
          { value: 'life', label: 'Life Insurance' },
          { value: 'motor', label: 'Motor Insurance' }
        ],
        commission_status: [
          { value: 'all', label: 'All Status' },
          { value: 'paid', label: 'Paid' },
          { value: 'pending', label: 'Pending' }
        ]
      }
    }
  end

  # GET /api/v1/mobile/agent/insurance_companies
  def insurance_companies
    page = params[:page]
    per_page = params[:per_page]
    search = params[:search]
    status_filter = params[:status] # 'active', 'inactive', or 'all'

    companies = InsuranceCompany.all

    # Apply search filter
    if search.present?
      companies = companies.where("name ILIKE ? OR code ILIKE ?", "%#{search}%", "%#{search}%")
    end

    # Apply status filter
    case status_filter
    when 'active'
      companies = companies.where(status: true)
    when 'inactive'
      companies = companies.where(status: false)
    # 'all' or nil shows all companies
    end

    companies = companies.order(:name)

    # Apply pagination only if page and per_page parameters are provided
    if page.present? && per_page.present?
      companies = companies.page(page).per(per_page)
      paginated = true
    else
      # Return all companies if no pagination parameters
      paginated = false
    end

    companies_data = companies.map do |company|
      # Map insurance_type to simplified categories
      type_mapping = {
        'life' => 'life',
        'health' => 'health',
        'motor' => 'motor_general',
        'motor_other' => 'motor_general',
        'general' => 'motor_general'
      }

      {
        id: company.id,
        name: company.name,
        code: company.code,
        type: type_mapping[company.insurance_type] || 'motor_general',
        status: company.status ? 'Active' : 'Inactive',
        contact_person: company.contact_person,
        email: company.email,
        mobile: company.mobile,
        address: company.address,
        created_at: company.created_at&.strftime('%Y-%m-%d %H:%M:%S'),
        updated_at: company.updated_at&.strftime('%Y-%m-%d %H:%M:%S')
      }
    end

    response_data = {
      insurance_companies: companies_data,
      statistics: {
        total_companies: InsuranceCompany.count,
        active_companies: InsuranceCompany.where(status: true).count,
        inactive_companies: InsuranceCompany.where(status: false).count
      }
    }

    # Add pagination info only if paginated
    if paginated
      response_data[:pagination] = {
        current_page: page.to_i,
        per_page: per_page.to_i,
        total_companies: companies.total_count,
        total_pages: companies.total_pages
      }
    else
      response_data[:pagination] = {
        current_page: 1,
        per_page: companies_data.length,
        total_companies: companies_data.length,
        total_pages: 1
      }
    end

    render json: {
      success: true,
      data: response_data
    }
  end

  # GET /api/v1/mobile/agent/motor_insurance_companies
  def motor_insurance_companies
    # Get companies with their types from the constants
    companies_with_types = MotorInsurance.insurance_companies.map do |company|
      {
        name: company[:name],
        type: company[:type].downcase
      }
    end

    render json: {
      success: true,
      data: {
        companies: companies_with_types,
        total_companies: companies_with_types.count,
        message: "Use exact company names from this list when creating motor insurance policies"
      }
    }
  end

  # GET /api/v1/mobile/agent/commission_distribution
  def commission_distribution
    agent = current_user
    page = params[:page] || 1
    per_page = params[:per_page] || 10
    period_filter = params[:period] # 'this_month', 'last_month', 'this_year', 'all'
    policy_type_filter = params[:policy_type] # 'health', 'life', 'motor', 'all'

    # Base query for sub-agent commission payouts
    commission_payouts = CommissionPayout.where(payout_to: 'sub_agent')

    # If agent is sub_agent type, filter by their records only
    if is_sub_agent?(agent)
      # Get policies associated with this sub-agent
      health_policies = HealthInsurance.where(sub_agent_id: agent.id).pluck(:id)
      life_policies = LifeInsurance.where(sub_agent_id: agent.id).pluck(:id)

      policy_ids = []
      policy_ids += health_policies if health_policies.any?
      policy_ids += life_policies if life_policies.any?

      commission_payouts = commission_payouts.where(
        "(policy_type = 'health' AND policy_id IN (?)) OR (policy_type = 'life' AND policy_id IN (?))",
        health_policies.any? ? health_policies : [0],
        life_policies.any? ? life_policies : [0]
      )
    end

    # Apply period filter
    case period_filter
    when 'this_month'
      start_date = Date.current.beginning_of_month
      end_date = Date.current.end_of_month
      commission_payouts = commission_payouts.where(payout_date: start_date..end_date)
    when 'last_month'
      start_date = 1.month.ago.beginning_of_month
      end_date = 1.month.ago.end_of_month
      commission_payouts = commission_payouts.where(payout_date: start_date..end_date)
    when 'this_year'
      start_date = Date.current.beginning_of_year
      end_date = Date.current.end_of_year
      commission_payouts = commission_payouts.where(payout_date: start_date..end_date)
    end

    # Apply policy type filter
    if policy_type_filter.present? && policy_type_filter != 'all'
      commission_payouts = commission_payouts.where(policy_type: policy_type_filter)
    end

    # Paginate
    commission_payouts = commission_payouts.order(payout_date: :desc).page(page).per(per_page)

    # Format commission data
    commissions_data = commission_payouts.map do |payout|
      policy = payout.policy

      {
        id: payout.id,
        policy_type: payout.policy_type.capitalize,
        policy_id: payout.policy_id,
        policy_number: policy&.policy_number || 'N/A',
        customer_name: policy&.customer&.display_name || 'N/A',
        payout_amount: payout.payout_amount,
        payout_date: payout.payout_date&.strftime('%Y-%m-%d'),
        status: payout.status.capitalize,
        created_at: payout.created_at.strftime('%Y-%m-%d %H:%M:%S')
      }
    end

    # Calculate statistics
    stats = get_commission_statistics(agent, period_filter, policy_type_filter)

    render json: {
      success: true,
      data: {
        commissions: commissions_data,
        statistics: stats,
        pagination: {
          current_page: page.to_i,
          per_page: per_page.to_i,
          total_commissions: commission_payouts.total_count,
          total_pages: commission_payouts.total_pages
        }
      }
    }
  end

  # GET /api/v1/mobile/agent/commission_summary
  def commission_summary
    agent = current_user

    # Get earnings summary
    summary = {
      total_earnings: 0.0,
      paid_earnings: 0.0,
      pending_earnings: 0.0,
      this_month_earnings: 0.0,
      last_month_earnings: 0.0,
      by_policy_type: {
        health: { total: 0.0, paid: 0.0, pending: 0.0 },
        life: { total: 0.0, paid: 0.0, pending: 0.0 },
        motor: { total: 0.0, paid: 0.0, pending: 0.0 }
      }
    }

    if is_sub_agent?(agent)
      # Calculate from sub-agent commission fields in policies
      health_policies = HealthInsurance.where(sub_agent_id: agent.id)
      life_policies = LifeInsurance.where(sub_agent_id: agent.id)

      # Health insurance commissions
      health_total = health_policies.sum(:sub_agent_after_tds_value) || 0.0
      summary[:by_policy_type][:health][:total] = health_total

      # Life insurance commissions
      life_total = life_policies.sum(:sub_agent_after_tds_value) || 0.0
      summary[:by_policy_type][:life][:total] = life_total

      summary[:total_earnings] = health_total + life_total

      # Get paid/pending from commission payouts
      health_policy_ids = health_policies.pluck(:id)
      life_policy_ids = life_policies.pluck(:id)

      paid_health = CommissionPayout.where(
        policy_type: 'health',
        policy_id: health_policy_ids,
        payout_to: 'sub_agent',
        status: 'paid'
      ).sum(:payout_amount)

      paid_life = CommissionPayout.where(
        policy_type: 'life',
        policy_id: life_policy_ids,
        payout_to: 'sub_agent',
        status: 'paid'
      ).sum(:payout_amount)

      summary[:paid_earnings] = paid_health + paid_life
      summary[:pending_earnings] = summary[:total_earnings] - summary[:paid_earnings]

      summary[:by_policy_type][:health][:paid] = paid_health
      summary[:by_policy_type][:health][:pending] = summary[:by_policy_type][:health][:total] - paid_health
      summary[:by_policy_type][:life][:paid] = paid_life
      summary[:by_policy_type][:life][:pending] = summary[:by_policy_type][:life][:total] - paid_life

      # This month earnings
      this_month_start = Date.current.beginning_of_month
      this_month_end = Date.current.end_of_month

      summary[:this_month_earnings] = CommissionPayout.where(
        "(policy_type = 'health' AND policy_id IN (?)) OR (policy_type = 'life' AND policy_id IN (?))",
        health_policy_ids.any? ? health_policy_ids : [0],
        life_policy_ids.any? ? life_policy_ids : [0]
      ).where(
        payout_to: 'sub_agent',
        status: 'paid',
        payout_date: this_month_start..this_month_end
      ).sum(:payout_amount)

      # Last month earnings
      last_month_start = 1.month.ago.beginning_of_month
      last_month_end = 1.month.ago.end_of_month

      summary[:last_month_earnings] = CommissionPayout.where(
        "(policy_type = 'health' AND policy_id IN (?)) OR (policy_type = 'life' AND policy_id IN (?))",
        health_policy_ids.any? ? health_policy_ids : [0],
        life_policy_ids.any? ? life_policy_ids : [0]
      ).where(
        payout_to: 'sub_agent',
        status: 'paid',
        payout_date: last_month_start..last_month_end
      ).sum(:payout_amount)
    else
      # For admin/agent, show all sub-agent commission data
      summary[:total_earnings] = CommissionPayout.where(payout_to: 'sub_agent').sum(:payout_amount)
      summary[:paid_earnings] = CommissionPayout.where(payout_to: 'sub_agent', status: 'paid').sum(:payout_amount)
      summary[:pending_earnings] = CommissionPayout.where(payout_to: 'sub_agent', status: 'pending').sum(:payout_amount)

      # By policy type
      ['health', 'life', 'motor'].each do |type|
        total = CommissionPayout.where(payout_to: 'sub_agent', policy_type: type).sum(:payout_amount)
        paid = CommissionPayout.where(payout_to: 'sub_agent', policy_type: type, status: 'paid').sum(:payout_amount)

        summary[:by_policy_type][type.to_sym] = {
          total: total,
          paid: paid,
          pending: total - paid
        }
      end
    end

    # Format amounts for API response
    formatted_summary = {
      total_earnings: format_indian_amount(summary[:total_earnings]),
      paid_earnings: format_indian_amount(summary[:paid_earnings]),
      pending_earnings: format_indian_amount(summary[:pending_earnings]),
      this_month_earnings: format_indian_amount(summary[:this_month_earnings]),
      last_month_earnings: format_indian_amount(summary[:last_month_earnings]),
      by_policy_type: {}
    }

    summary[:by_policy_type].each do |type, amounts|
      formatted_summary[:by_policy_type][type] = {
        total: format_indian_amount(amounts[:total]),
        paid: format_indian_amount(amounts[:paid]),
        pending: format_indian_amount(amounts[:pending])
      }
    end

    render json: {
      success: true,
      data: formatted_summary
    }
  end

  private

  def get_customer_policies_with_documents(customer, commission_payouts)
    policies = []
    agent = current_user

    # Only show policies where the current agent is affiliated
    if is_admin?(agent)
      # Admin can see all policies for the customer
      customer.health_insurances.includes(:health_insurance_documents, documents_attachments: :blob, policy_documents_attachments: :blob).each do |policy|
        policies << format_policy_data_with_commission(policy, 'Health', commission_payouts)
      end

      customer.life_insurances.includes(:life_insurance_documents).each do |policy|
        policies << format_policy_data_with_commission(policy, 'Life', commission_payouts)
      end

      customer.motor_insurances.includes(:motor_insurance_documents).each do |policy|
        policies << format_policy_data_with_commission(policy, 'Motor', commission_payouts)
      end

      customer.policies.where(insurance_type: 'other').includes(documents_attachments: :blob, policy_documents_attachments: :blob).each do |policy|
        policies << format_policy_data_with_commission(policy, 'Other', commission_payouts)
      end
    elsif agent.is_a?(SubAgent)
      # For SubAgents, only show policies where they are the sub_agent
      customer.health_insurances.where(sub_agent_id: agent.id).includes(documents_attachments: :blob, policy_documents_attachments: :blob).each do |policy|
        policies << format_policy_data_with_commission(policy, 'Health', commission_payouts)
      end

      customer.life_insurances.where(sub_agent_id: agent.id).includes(:life_insurance_documents).each do |policy|
        policies << format_policy_data_with_commission(policy, 'Life', commission_payouts)
      end

      customer.motor_insurances.where(sub_agent_id: agent.id).includes(:motor_insurance_documents).each do |policy|
        policies << format_policy_data_with_commission(policy, 'Motor', commission_payouts)
      end

      # Note: Other insurance (Policy model) doesn't have sub_agent_id, so sub_agents won't see these
    else
      # For regular User agents, filter using the same logic as get_agent_policies
      health_policies, life_policies, motor_policies, _ = get_agent_policies(agent)

      # Filter customer's policies to only include agent-affiliated ones
      customer_health_ids = customer.health_insurances.pluck(:id)
      customer_life_ids = customer.life_insurances.pluck(:id)
      customer_motor_ids = customer.motor_insurances.pluck(:id)

      # Only include policies that are both customer's and agent-affiliated
      health_policies.where(id: customer_health_ids).includes(documents_attachments: :blob, policy_documents_attachments: :blob).each do |policy|
        policies << format_policy_data_with_commission(policy, 'Health', commission_payouts)
      end

      life_policies.where(id: customer_life_ids).includes(:life_insurance_documents).each do |policy|
        policies << format_policy_data_with_commission(policy, 'Life', commission_payouts)
      end

      motor_policies.where(id: customer_motor_ids).includes(:motor_insurance_documents).each do |policy|
        policies << format_policy_data_with_commission(policy, 'Motor', commission_payouts)
      end

      # For other insurance policies, filter by agent (if applicable)
      customer.policies.where(insurance_type: 'other', user: agent).includes(documents_attachments: :blob, policy_documents_attachments: :blob).each do |policy|
        policies << format_policy_data_with_commission(policy, 'Other', commission_payouts)
      end
    end

    # Sort by creation date (newest first)
    policies.sort_by { |p| -p[:created_at].to_time.to_i }
  end

  def determine_drwise_policy(policy)
    # DR wise policy: Only admin added (not customer or agent added)
    # is_customer_added: false && is_agent_added: false && is_admin_added: true

    # Check if the policy object has these methods (specific insurance models do, Policy doesn't)
    if policy.respond_to?(:is_customer_added) && policy.respond_to?(:is_agent_added) && policy.respond_to?(:is_admin_added)
      !policy.is_customer_added && !policy.is_agent_added && policy.is_admin_added
    else
      # For Policy objects or models without these fields, check through specific_insurance if available
      if policy.respond_to?(:specific_insurance) && policy.specific_insurance
        specific = policy.specific_insurance
        if specific.respond_to?(:is_customer_added) && specific.respond_to?(:is_agent_added) && specific.respond_to?(:is_admin_added)
          !specific.is_customer_added && !specific.is_agent_added && specific.is_admin_added
        else
          # Default to false for models without these tracking fields
          false
        end
      else
        # Default to false for Policy objects without specific_insurance
        false
      end
    end
  end

  def authenticate_agent!
    token = request.headers['Authorization']&.split(' ')&.last

    if token.blank?
      return render json: {
        success: false,
        message: 'Authorization token is required'
      }, status: :unauthorized
    end

    begin
      decoded_token = JWT.decode(token, Rails.application.secret_key_base)[0]
      user_id = decoded_token['user_id']
      role = decoded_token['role']

      if role == 'agent'
        @current_user = User.find(user_id)
      elsif role == 'sub_agent'
        @current_user = SubAgent.find(user_id)
      else
        return render json: {
          success: false,
          message: 'Agent authorization required'
        }, status: :unauthorized
      end

      if @current_user.nil?
        return render json: {
          success: false,
          message: 'Agent not found'
        }, status: :unauthorized
      end

    rescue JWT::DecodeError => e
      render json: {
        success: false,
        message: 'Invalid authorization token'
      }, status: :unauthorized
    rescue ActiveRecord::RecordNotFound => e
      render json: {
        success: false,
        message: 'Agent not found'
      }, status: :unauthorized
    end
  end

  def get_dashboard_statistics(agent)
    if is_admin?(agent)
      # Admin can see all statistics - optimized queries
      admin_stats = get_optimized_admin_stats

      {
        customers_count: admin_stats[:customers_count],
        active_customers: admin_stats[:active_customers],
        inactive_customers: admin_stats[:inactive_customers],
        policies_count: admin_stats[:total_policies],
        health_policies_count: admin_stats[:health_count],
        life_policies_count: admin_stats[:life_count],
        motor_policies_count: admin_stats[:motor_count],
        total_premium: admin_stats[:total_premium],
        total_sum_insured: admin_stats[:total_sum_insured],
        commission_earned: admin_stats[:total_commission],
        this_month_policies: admin_stats[:monthly_policies],
        this_month_premium: admin_stats[:monthly_premium],
        policy_distribution: {
          health: { count: admin_stats[:health_count], percentage: admin_stats[:health_percentage] },
          life: { count: admin_stats[:life_count], percentage: admin_stats[:life_percentage] },
          motor: { count: admin_stats[:motor_count], percentage: admin_stats[:motor_percentage] }
        },
        performance_metrics: {
          new_customers_this_month: admin_stats[:new_customers_month],
          renewal_due: admin_stats[:renewal_due],
          expired_policies: admin_stats[:expired_policies]
        }
      }
    elsif agent.is_a?(SubAgent)
      # SubAgent statistics - optimized for real-time data
      sub_agent_stats = get_optimized_sub_agent_stats(agent)

      {
        customers_count: sub_agent_stats[:customers_count],
        policies_count: sub_agent_stats[:total_policies],
        health_policies_count: sub_agent_stats[:health_count],
        life_policies_count: sub_agent_stats[:life_count],
        motor_policies_count: sub_agent_stats[:motor_count],
        total_premium: sub_agent_stats[:total_premium],
        total_sum_insured: sub_agent_stats[:total_sum_insured],
        commission_earned: sub_agent_stats[:commission_earned],
        this_month_policies: sub_agent_stats[:monthly_policies],
        this_month_premium: sub_agent_stats[:monthly_premium],
        this_month_customers: sub_agent_stats[:monthly_customers],
        policy_distribution: {
          health: { count: sub_agent_stats[:health_count], percentage: sub_agent_stats[:health_percentage] },
          life: { count: sub_agent_stats[:life_count], percentage: sub_agent_stats[:life_percentage] },
          motor: { count: sub_agent_stats[:motor_count], percentage: sub_agent_stats[:motor_percentage] }
        },
        performance_metrics: {
          conversion_rate: sub_agent_stats[:conversion_rate],
          commission_this_month: sub_agent_stats[:commission_this_month],
          target_achievement: sub_agent_stats[:target_achievement]
        }
      }
    else
      # Regular agents - optimized queries
      agent_stats = get_optimized_agent_stats(agent)

      {
        customers_count: agent_stats[:customers_count],
        policies_count: agent_stats[:total_policies],
        health_policies_count: agent_stats[:health_count],
        life_policies_count: agent_stats[:life_count],
        total_premium: agent_stats[:total_premium],
        commission_earned: agent_stats[:commission_earned],
        this_month_policies: agent_stats[:monthly_policies],
        this_month_premium: agent_stats[:monthly_premium],
        policy_distribution: {
          health: { count: agent_stats[:health_count], percentage: agent_stats[:health_percentage] },
          life: { count: agent_stats[:life_count], percentage: agent_stats[:life_percentage] }
        }
      }
    end
  end

  def get_recent_activities(agent)
    activities = []

    if is_admin?(agent)
      # Admin can see all recent policies
      recent_health = HealthInsurance.order(created_at: :desc).limit(5)
      recent_life = LifeInsurance.order(created_at: :desc).limit(5)
    elsif agent.is_a?(SubAgent)
      # For SubAgents, get their policies directly
      recent_health = HealthInsurance.where(sub_agent_id: agent.id).order(created_at: :desc).limit(5)
      recent_life = LifeInsurance.where(sub_agent_id: agent.id).order(created_at: :desc).limit(5)
      recent_motor = MotorInsurance.where(sub_agent_id: agent.id).order(created_at: :desc).limit(5)
    else
      # For User agents, use the cross-reference helper to get their policies
      agent_health_policies, agent_life_policies, agent_motor_policies, _ = get_agent_policies(agent)
      recent_health = agent_health_policies.order(created_at: :desc).limit(5)
      recent_life = agent_life_policies.order(created_at: :desc).limit(5)
      recent_motor = agent_motor_policies.order(created_at: :desc).limit(5)
    end

    recent_health.each do |policy|
      activities << {
        type: 'policy_created',
        message: "Health insurance policy #{policy.policy_number} created for #{policy.customer&.display_name || 'Customer'}",
        timestamp: policy.created_at,
        policy_type: 'Health'
      }
    end

    recent_life.each do |policy|
      activities << {
        type: 'policy_created',
        message: "Life insurance policy #{policy.policy_number} created for #{policy.customer&.display_name || 'Customer'}",
        timestamp: policy.created_at,
        policy_type: 'Life'
      }
    end

    # Add motor insurance activities if recent_motor is defined
    if defined?(recent_motor) && recent_motor
      recent_motor.each do |policy|
        activities << {
          type: 'policy_created',
          message: "Motor insurance policy #{policy.policy_number} created for #{policy.customer&.display_name || 'Customer'}",
          timestamp: policy.created_at,
          policy_type: 'Motor'
        }
      end
    end

    activities.sort_by { |a| a[:timestamp] }.reverse.first(10)
  end

  def get_customer_policies_count(customer)
    agent = current_user

    if is_admin?(agent)
      # Admin can see all policies
      HealthInsurance.where(customer: customer).count +
      LifeInsurance.where(customer: customer).count +
      MotorInsurance.where(customer: customer).count
    elsif agent.is_a?(SubAgent)
      # SubAgents only see their affiliated policies
      HealthInsurance.where(customer: customer, sub_agent_id: agent.id).count +
      LifeInsurance.where(customer: customer, sub_agent_id: agent.id).count +
      MotorInsurance.where(customer: customer, sub_agent_id: agent.id).count
    else
      # Regular agents only see their affiliated policies
      health_policies, life_policies, motor_policies, _ = get_agent_policies(agent)
      customer_health_ids = customer.health_insurances.pluck(:id)
      customer_life_ids = customer.life_insurances.pluck(:id)
      customer_motor_ids = customer.motor_insurances.pluck(:id)

      health_policies.where(id: customer_health_ids).count +
      life_policies.where(id: customer_life_ids).count +
      motor_policies.where(id: customer_motor_ids).count
    end
  end

  def get_customer_total_premium(customer)
    agent = current_user

    if is_admin?(agent)
      # Admin can see all policies
      HealthInsurance.where(customer: customer).sum(:total_premium) +
      LifeInsurance.where(customer: customer).sum(:total_premium) +
      MotorInsurance.where(customer: customer).sum(:total_premium)
    elsif agent.is_a?(SubAgent)
      # SubAgents only see their affiliated policies
      HealthInsurance.where(customer: customer, sub_agent_id: agent.id).sum(:total_premium) +
      LifeInsurance.where(customer: customer, sub_agent_id: agent.id).sum(:total_premium) +
      MotorInsurance.where(customer: customer, sub_agent_id: agent.id).sum(:total_premium)
    else
      # Regular agents only see their affiliated policies
      health_policies, life_policies, motor_policies, _ = get_agent_policies(agent)
      customer_health_ids = customer.health_insurances.pluck(:id)
      customer_life_ids = customer.life_insurances.pluck(:id)
      customer_motor_ids = customer.motor_insurances.pluck(:id)

      health_policies.where(id: customer_health_ids).sum(:total_premium) +
      life_policies.where(id: customer_life_ids).sum(:total_premium) +
      motor_policies.where(id: customer_motor_ids).sum(:total_premium)
    end
  end

  def format_policy_data(policy, type)
    # Fallback method for backward compatibility
    format_policy_data_with_commission(policy, type, {})
  end

  def format_policy_data_with_commission(policy, type, commission_payouts_hash)
    # Fetch commission data from preloaded commission_payouts hash
    agent_percentage = 0
    agent_commission = 0

    # Determine the policy type for commission lookup
    policy_type_key = type.downcase

    # Look up commission payout from preloaded hash
    commission_key = "#{policy_type_key}:#{policy.id}"
    commission_payout = commission_payouts_hash[commission_key]

    if commission_payout
      agent_commission = commission_payout.payout_amount || 0

      # Calculate percentage if we have premium and commission
      if policy.total_premium.present? && policy.total_premium.to_f > 0 && agent_commission > 0
        agent_percentage = ((agent_commission.to_f / policy.total_premium.to_f) * 100).round(2)
      else
        agent_percentage = commission_payout.distribution_percentage || 0
      end
    end

    # Build full documents list — R2 first, then Active Storage fallbacks
    all_documents = []

    # 1. R2 main policy document (stored as columns on the policy record)
    if policy.respond_to?(:main_policy_document_key) && policy.main_policy_document_key.present?
      all_documents << {
        title: policy.respond_to?(:main_policy_document_filename) ? (policy.main_policy_document_filename.presence || 'Main Policy Document') : 'Main Policy Document',
        document_type: 'policy_document',
        url: policy.main_policy_r2_url,
        filename: policy.respond_to?(:main_policy_document_filename) ? policy.main_policy_document_filename : nil,
        size: policy.respond_to?(:main_policy_document_size) ? policy.main_policy_document_size : nil,
        is_main: true
      }
    end

    # 2. R2 documents from health_insurance_documents association
    if type.downcase == 'health' && policy.respond_to?(:health_insurance_documents)
      policy.health_insurance_documents.each do |doc|
        next unless doc.r2_file_key.present?
        all_documents << {
          title: doc.title.presence || doc.r2_filename,
          document_type: doc.document_type,
          url: doc.document_url,
          filename: doc.r2_filename,
          size: doc.r2_file_size,
          is_main: false
        }
      end
    end

    # 3. R2 documents from motor_insurance_documents association
    if type.downcase == 'motor' && policy.respond_to?(:motor_insurance_documents)
      policy.motor_insurance_documents.each do |doc|
        next unless doc.r2_file_key.present?
        all_documents << {
          title: doc.respond_to?(:title) ? doc.title.presence : nil,
          document_type: doc.respond_to?(:document_type) ? doc.document_type : 'other',
          url: doc.document_url,
          filename: doc.respond_to?(:r2_filename) ? doc.r2_filename : nil,
          size: doc.respond_to?(:r2_file_size) ? doc.r2_file_size : nil,
          is_main: false
        }
      end
    end

    # 4. Active Storage life_insurance_documents
    if type.downcase == 'life' && policy.respond_to?(:life_insurance_documents)
      policy.life_insurance_documents.each do |doc_record|
        next unless doc_record.document.attached?
        all_documents << {
          title: doc_record.respond_to?(:document_name) ? doc_record.document_name : (doc_record.document_type || 'Life Insurance Document'),
          document_type: doc_record.document_type || 'other',
          url: begin
                 Rails.application.routes.url_helpers.rails_blob_url(doc_record.document, host: 'dr-wise-ag.onrender.com', protocol: 'https')
               rescue
                 nil
               end,
          filename: doc_record.document.filename.to_s,
          size: doc_record.document.byte_size,
          is_main: false
        }
      end
    end

    # 5. Fallback — Active Storage :documents / :policy_documents (legacy)
    if all_documents.empty?
      [:documents, :policy_documents].each do |attachment_name|
        next unless policy.respond_to?(attachment_name) && policy.send(attachment_name).attached?
        policy.send(attachment_name).each do |doc|
          all_documents << {
            title: 'Policy Document',
            document_type: 'policy_document',
            url: begin
                   Rails.application.routes.url_helpers.rails_blob_url(doc, host: 'dr-wise-ag.onrender.com', protocol: 'https')
                 rescue
                   nil
                 end,
            filename: doc.filename.to_s,
            size: doc.byte_size,
            is_main: all_documents.empty?
          }
        end
      end
    end

    {
      id: policy.id,
      insurance_name: policy.plan_name || "#{type} Insurance",
      insurance_type: type,
      policy_number: policy.policy_number,
      client_name: policy.customer&.display_name || 'N/A',
      policy_type: policy.policy_type || 'New',
      policy_holder: policy.policy_holder,
      entry_date: policy.created_at&.strftime('%Y-%m-%d'),
      start_date: policy.policy_start_date&.strftime('%Y-%m-%d'),
      end_date: policy.policy_end_date&.strftime('%Y-%m-%d'),
      total_premium: format_indian_amount(policy.total_premium),
      sum_insured: format_indian_amount(policy.sum_insured),
      insurance_company: policy.respond_to?(:specific_insurance) ?
                          (policy.specific_insurance&.insurance_company_name || policy.insurance_company&.name) :
                          policy.insurance_company_name,
      payment_mode: policy.payment_mode,
      commission_amount: format_indian_amount(agent_commission),
      agent_percentage: agent_percentage,
      agent_commission: format_indian_amount(agent_commission),
      status: policy.respond_to?(:active?) ? (policy.active? ? 'Active' : 'Inactive') : 'Active',
      is_drwise_policy: determine_drwise_policy(policy),
      drwise: policy.respond_to?(:is_admin_added) ? (policy.is_admin_added == true) : false,
      dr_wise: policy.respond_to?(:is_admin_added) ? (policy.is_admin_added == true) : false,
      document: all_documents.first&.dig(:url),
      documents: all_documents,
      created_at: policy.created_at
    }
  end

  def get_insurance_companies
    # Use centralized insurance company data from InsuranceCompanyConstants
    self.class.insurance_company_names
  end

  # New helper methods for form data
  def get_clients_dropdown
    # Get all active customers
    Customer.active.limit(100).map do |customer|
      {
        id: customer.id,
        name: customer.display_name,
        email: customer.email,
        mobile: customer.mobile
      }
    end
  end

  def get_insurance_companies_dropdown
    # Use centralized insurance company data from InsuranceCompanyConstants
    companies = self.class.insurance_company_names

    companies.map.with_index(1) do |company, index|
      {
        id: index,
        name: company
      }
    end
  end

  def get_this_month_policies_count
    start_date = Date.current.beginning_of_month
    end_date = Date.current.end_of_month

    HealthInsurance.where(created_at: start_date..end_date).count +
    LifeInsurance.where(created_at: start_date..end_date).count
  end

  def get_this_month_premium
    start_date = Date.current.beginning_of_month
    end_date = Date.current.end_of_month

    HealthInsurance.where(created_at: start_date..end_date).sum(:total_premium) +
    LifeInsurance.where(created_at: start_date..end_date).sum(:total_premium)
  end

  def get_this_month_policies_count_for_agent(agent)
    start_date = Date.current.beginning_of_month
    end_date = Date.current.end_of_month

    agent_health_policies, agent_life_policies, agent_motor_policies, _ = get_agent_policies(agent)

    agent_health_policies.where(created_at: start_date..end_date).count +
    agent_life_policies.where(created_at: start_date..end_date).count +
    agent_motor_policies.where(created_at: start_date..end_date).count
  end

  def get_this_month_premium_for_agent(agent)
    start_date = Date.current.beginning_of_month
    end_date = Date.current.end_of_month

    agent_health_policies, agent_life_policies, agent_motor_policies, _ = get_agent_policies(agent)

    agent_health_policies.where(created_at: start_date..end_date).sum(:total_premium) +
    agent_life_policies.where(created_at: start_date..end_date).sum(:total_premium) +
    agent_motor_policies.where(created_at: start_date..end_date).sum(:total_premium)
  end

  def get_this_month_policies_count_for_sub_agent(sub_agent)
    start_date = Date.current.beginning_of_month
    end_date = Date.current.end_of_month

    sub_agent_health_policies = HealthInsurance.where(sub_agent_id: sub_agent.id)
    sub_agent_life_policies = LifeInsurance.where(sub_agent_id: sub_agent.id)

    sub_agent_health_policies.where(created_at: start_date..end_date).count +
    sub_agent_life_policies.where(created_at: start_date..end_date).count
  end

  def get_this_month_premium_for_sub_agent(sub_agent)
    start_date = Date.current.beginning_of_month
    end_date = Date.current.end_of_month

    sub_agent_health_policies = HealthInsurance.where(sub_agent_id: sub_agent.id)
    sub_agent_life_policies = LifeInsurance.where(sub_agent_id: sub_agent.id)

    sub_agent_health_policies.where(created_at: start_date..end_date).sum(:total_premium) +
    sub_agent_life_policies.where(created_at: start_date..end_date).sum(:total_premium)
  end

  def get_agent_policies(agent)
    # This method handles the cross-reference between User and SubAgent models
    if agent.is_a?(User)
      # For User model agents, check if there's a corresponding SubAgent with same email
      sub_agent = SubAgent.find_by(email: agent.email)
      if sub_agent
        # If there's a matching SubAgent, use that for policy lookup
        agent_health_policies = HealthInsurance.where(sub_agent_id: sub_agent.id)
        agent_life_policies = LifeInsurance.where(sub_agent_id: sub_agent.id)
        agent_motor_policies = MotorInsurance.where(sub_agent_id: sub_agent.id)
      else
        # If no matching SubAgent, use the User ID directly
        agent_health_policies = HealthInsurance.where(sub_agent_id: agent.id)
        agent_life_policies = LifeInsurance.where(sub_agent_id: agent.id)
        agent_motor_policies = MotorInsurance.where(sub_agent_id: agent.id)
      end
    elsif agent.is_a?(SubAgent)
      # For SubAgent model, use ID directly
      agent_health_policies = HealthInsurance.where(sub_agent_id: agent.id)
      agent_life_policies = LifeInsurance.where(sub_agent_id: agent.id)
      agent_motor_policies = MotorInsurance.where(sub_agent_id: agent.id)
    else
      # Fallback: empty relations
      agent_health_policies = HealthInsurance.none
      agent_life_policies = LifeInsurance.none
      agent_motor_policies = MotorInsurance.none
    end

    agent_customer_ids = (agent_health_policies.pluck(:customer_id) + agent_life_policies.pluck(:customer_id) + agent_motor_policies.pluck(:customer_id)).uniq

    [agent_health_policies, agent_life_policies, agent_motor_policies, agent_customer_ids]
  end

  def generate_demo_password(customer)
    # Generate a consistent demo password based on customer data
    # Format: first_name + last 4 digits of mobile + "123"
    first_name = customer.first_name&.downcase || 'customer'
    mobile_suffix = customer.mobile&.last(4) || '0000'
    "#{first_name}#{mobile_suffix}123"
  end

  def determine_add_source(added_by_field)
    return 'system' if added_by_field.blank?
    return 'mobile_api' if added_by_field.include?('agent_mobile_api_')
    return 'admin_panel' if added_by_field.include?('admin')
    'other'
  end

  def get_customer_statistics(agent)
    base_customers = if is_admin?(agent)
                      Customer.all
                    elsif agent.is_a?(SubAgent)
                      # For SubAgents, only count customers from their policies
                      sub_agent_health_policies = HealthInsurance.where(sub_agent_id: agent.id)
                      sub_agent_life_policies = LifeInsurance.where(sub_agent_id: agent.id)
                      sub_agent_motor_policies = MotorInsurance.where(sub_agent_id: agent.id)
                      policy_customer_ids = (sub_agent_health_policies.pluck(:customer_id) + sub_agent_life_policies.pluck(:customer_id) + sub_agent_motor_policies.pluck(:customer_id)).uniq
                      Customer.where(id: policy_customer_ids)
                    else
                      # For regular User agents, only count customers from their policies
                      _, _, _, agent_customer_ids = get_agent_policies(agent)
                      Customer.where(id: agent_customer_ids)
                    end

    {
      total_customers: base_customers.active.count,
      agent_added_customers: base_customers.where("added_by LIKE ?", "%agent_mobile_api_%").count,
      system_added_customers: base_customers.where("added_by IS NULL OR added_by NOT LIKE ?", "%agent_mobile_api_%").count,
      my_added_customers: !is_admin?(agent) ? base_customers.where("added_by LIKE ?", "%agent_mobile_api_#{agent.id}%").count : 0
    }
  end

  # Helper methods for health policy creation
  def parse_date(date_string)
    return nil if date_string.blank?
    begin
      Date.parse(date_string)
    rescue
      nil
    end
  end

  def get_company_name_by_id(company_id)
    # Try to get company name from InsuranceCompany model first
    if defined?(InsuranceCompany)
      company = InsuranceCompany.find_by(id: company_id)
      return company.name if company
    end

    # Fallback to hardcoded mapping with more companies
    companies = {
      1 => 'ICICI Prudential Life Insurance Co Ltd',
      2 => 'Bajaj Allianz General Insurance Company Limited',
      3 => 'HDFC ERGO General Insurance Co Ltd',
      4 => 'Care Health Insurance Ltd',
      5 => 'Star Health Allied Insurance Co Ltd',
      6 => 'Aditya Birla Health Insurance Co Ltd',
      7 => 'Niva Bupa Health Insurance Co Ltd',
      8 => 'Tata AIG General Insurance Co Ltd',
      37 => 'Bajaj Allianz General Insurance Company Limited'
    }
    companies[company_id.to_i] || 'ICICI Prudential Life Insurance Co Ltd'
  end

  def create_family_member(policy, member_data)
    # Use the existing HealthInsuranceMember model if it exists
    if defined?(HealthInsuranceMember)
      HealthInsuranceMember.create!(
        health_insurance: policy,
        member_name: member_data[:full_name],
        age: member_data[:age],
        relationship: member_data[:relationship],
        sum_insured: member_data[:sum_insured]
      )
    else
      # Store in notes field as JSON if no separate table exists
      family_member = {
        full_name: member_data[:full_name],
        age: member_data[:age],
        relationship: member_data[:relationship],
        sum_insured: member_data[:sum_insured]
      }

      current_notes = policy.notes.present? ? JSON.parse(policy.notes) : {}
      current_notes['family_members'] ||= []
      current_notes['family_members'] << family_member
      policy.update(notes: current_notes.to_json)
    end
  end

  def handle_document_uploads(policy, documents_data)
    # Handle base64 document uploads using Active Storage
    documents_data.each_with_index do |doc_data, index|
      next if doc_data[:document_file].blank?

      begin
        # Decode base64 file
        decoded_file = Base64.decode64(doc_data[:document_file])

        # Create filename
        filename = "#{doc_data[:document_type]}_#{policy.policy_number}_#{index + 1}.pdf"

        # Create a StringIO object for Active Storage
        file_io = StringIO.new(decoded_file)
        file_io.set_encoding('BINARY')

        # Attach to the policy using Active Storage
        policy.documents.attach(
          io: file_io,
          filename: filename,
          content_type: 'application/pdf'
        )

        Rails.logger.info "Document uploaded successfully: #{filename}"
      rescue => e
        Rails.logger.error "Error processing document #{index}: #{e.message}"
      end
    end
  end

  # Helper method for leads statistics
  def get_leads_statistics
    current_month_start = Date.current.beginning_of_month
    current_month_end = Date.current.end_of_month

    {
      total_leads: Lead.count,
      this_month_leads: Lead.where(created_date: current_month_start..current_month_end).count,
      pending_leads: Lead.pending_conversion.count,
      converted_leads: Lead.converted_leads.count,
      conversion_rate: calculate_conversion_rate,
      by_stage: {
        consultation_scheduled: Lead.by_stage('consultation_scheduled').count,
        one_on_one: Lead.by_stage('one_on_one').count,
        follow_up: Lead.by_stage('follow_up').count,
        converted: Lead.by_stage('converted').count,
        lead_closed: Lead.by_stage('lead_closed').count
      },
      by_product: {
        health: Lead.by_product('health').count,
        life: Lead.by_product('life').count,
        motor: Lead.by_product('motor').count,
        home: Lead.by_product('home').count,
        travel: Lead.by_product('travel').count,
        other: Lead.by_product('other').count
      },
      by_source: {
        online: Lead.by_source('online').count,
        offline: Lead.by_source('offline').count,
        agent_referral: Lead.by_source('agent_referral').count,
        walk_in: Lead.by_source('walk_in').count,
        tele_calling: Lead.by_source('tele_calling').count,
        campaign: Lead.by_source('campaign').count
      }
    }
  end

  def get_leads_statistics_for_user(agent)
    current_month_start = Date.current.beginning_of_month
    current_month_end = Date.current.end_of_month

    # Base query for leads based on user type
    base_leads_query = if is_admin?(agent)
      Lead.all
    elsif is_sub_agent?(agent)
      if agent.is_a?(SubAgent)
        Lead.where(affiliate_id: agent.id)
      else
        sub_agent = SubAgent.find_by(email: agent.email)
        if sub_agent
          Lead.where(affiliate_id: sub_agent.id)
        else
          Lead.where(affiliate_id: agent.id)
        end
      end
    else
      Lead.where(is_direct: true)
    end

    {
      total_leads: base_leads_query.count,
      this_month_leads: base_leads_query.where(created_date: current_month_start..current_month_end).count,
      pending_leads: base_leads_query.pending_conversion.count,
      converted_leads: base_leads_query.converted_leads.count,
      conversion_rate: calculate_conversion_rate_for_query(base_leads_query),
      by_stage: {
        consultation_scheduled: base_leads_query.by_stage('consultation_scheduled').count,
        one_on_one: base_leads_query.by_stage('one_on_one').count,
        follow_up: base_leads_query.by_stage('follow_up').count,
        converted: base_leads_query.by_stage('converted').count,
        lead_closed: base_leads_query.by_stage('lead_closed').count
      },
      by_product: {
        health: base_leads_query.by_product('health').count,
        life: base_leads_query.by_product('life').count,
        motor: base_leads_query.by_product('motor').count,
        home: base_leads_query.by_product('home').count,
        travel: base_leads_query.by_product('travel').count,
        other: base_leads_query.by_product('other').count
      },
      by_source: {
        online: base_leads_query.by_source('online').count,
        offline: base_leads_query.by_source('offline').count,
        agent_referral: base_leads_query.by_source('agent_referral').count,
        walk_in: base_leads_query.by_source('walk_in').count,
        tele_calling: base_leads_query.by_source('tele_calling').count,
        campaign: base_leads_query.by_source('campaign').count
      }
    }
  end

  def calculate_conversion_rate
    total_leads = Lead.count
    return 0 if total_leads == 0

    converted_leads = Lead.converted_leads.count
    ((converted_leads.to_f / total_leads) * 100).round(2)
  end

  def calculate_conversion_rate_for_query(leads_query)
    total_leads = leads_query.count
    return 0 if total_leads == 0

    converted_leads = leads_query.converted_leads.count
    ((converted_leads.to_f / total_leads) * 100).round(2)
  end

  def get_indian_states
    [
      { value: 'andhra_pradesh', label: 'Andhra Pradesh' },
      { value: 'assam', label: 'Assam' },
      { value: 'bihar', label: 'Bihar' },
      { value: 'delhi', label: 'Delhi' },
      { value: 'gujarat', label: 'Gujarat' },
      { value: 'haryana', label: 'Haryana' },
      { value: 'karnataka', label: 'Karnataka' },
      { value: 'kerala', label: 'Kerala' },
      { value: 'madhya_pradesh', label: 'Madhya Pradesh' },
      { value: 'maharashtra', label: 'Maharashtra' },
      { value: 'punjab', label: 'Punjab' },
      { value: 'rajasthan', label: 'Rajasthan' },
      { value: 'tamil_nadu', label: 'Tamil Nadu' },
      { value: 'uttar_pradesh', label: 'Uttar Pradesh' },
      { value: 'west_bengal', label: 'West Bengal' }
    ]
  end

  # Helper method to handle customer file uploads
  def handle_customer_file_uploads(customer, file1, file2)
    file_info = {
      file1: nil,
      file2: nil,
      upload_status: 'success',
      upload_errors: []
    }

    begin
      # Handle file1 upload
      if file1.present?
        file1_result = process_customer_file(customer, file1, 'file1')
        file_info[:file1] = file1_result
      end

      # Handle file2 upload
      if file2.present?
        file2_result = process_customer_file(customer, file2, 'file2')
        file_info[:file2] = file2_result
      end

    rescue => e
      file_info[:upload_status] = 'error'
      file_info[:upload_errors] << e.message
      Rails.logger.error "Error processing customer files: #{e.message}"
    end

    file_info
  end

  def process_customer_file(customer, file_data, file_type)
    return nil if file_data.blank?

    begin
      # If it's a base64 string, decode it
      if file_data.is_a?(String) && file_data.start_with?('data:')
        # Extract file info from data URL
        data_match = file_data.match(/^data:([^;]+);base64,(.+)$/)
        if data_match
          content_type = data_match[1]
          encoded_file = data_match[2]
          decoded_file = Base64.decode64(encoded_file)

          # Determine file extension from content type
          extension = case content_type
                     when 'image/jpeg', 'image/jpg' then '.jpg'
                     when 'image/png' then '.png'
                     when 'image/gif' then '.gif'
                     when 'application/pdf' then '.pdf'
                     when 'image/webp' then '.webp'
                     else '.bin'
                     end

          # Create filename
          filename = "customer_#{customer.id}_#{file_type}_#{Time.current.to_i}#{extension}"

          # Create a StringIO object for Active Storage
          file_io = StringIO.new(decoded_file)
          file_io.set_encoding('BINARY')

          # Attach to customer using Active Storage
          customer.documents.attach(
            io: file_io,
            filename: filename,
            content_type: content_type
          )

          return {
            filename: filename,
            content_type: content_type,
            file_size: decoded_file.size,
            uploaded_at: Time.current.strftime('%Y-%m-%d %H:%M:%S'),
            type: file_type
          }
        end
      end

      # Handle direct file uploads (multipart)
      if file_data.respond_to?(:original_filename)
        filename = "customer_#{customer.id}_#{file_type}_#{Time.current.to_i}_#{file_data.original_filename}"

        customer.documents.attach(
          io: file_data.tempfile,
          filename: filename,
          content_type: file_data.content_type
        )

        return {
          filename: filename,
          content_type: file_data.content_type,
          file_size: file_data.size,
          uploaded_at: Time.current.strftime('%Y-%m-%d %H:%M:%S'),
          type: file_type
        }
      end

    rescue => e
      Rails.logger.error "Error processing #{file_type}: #{e.message}"
      return {
        error: "Failed to process #{file_type}",
        message: e.message
      }
    end

    nil
  end

  def handle_customer_documents(customer, documents_array)
    return unless documents_array.present?

    documents_array.each do |document_data|
      next unless document_data[:document_type].present? && document_data[:document_file].present?

      begin
        # Skip if document_file is just a placeholder
        next if document_data[:document_file] == "base64_encoded_pdf_string_here"

        # Handle the document file (base64 or direct upload)
        if document_data[:document_file].is_a?(String) && document_data[:document_file].start_with?('data:')
          # Handle base64 encoded file
          data_match = document_data[:document_file].match(/^data:([^;]+);base64,(.+)$/)
          if data_match
            content_type = data_match[1]
            encoded_file = data_match[2]
            decoded_file = Base64.decode64(encoded_file)

            # Determine file extension
            extension = case content_type
                       when 'image/jpeg', 'image/jpg' then '.jpg'
                       when 'image/png' then '.png'
                       when 'image/gif' then '.gif'
                       when 'application/pdf' then '.pdf'
                       when 'image/webp' then '.webp'
                       else '.bin'
                       end

            filename = "customer_#{customer.id}_#{document_data[:document_type]}_#{Time.current.to_i}#{extension}"

            file_io = StringIO.new(decoded_file)
            file_io.set_encoding('BINARY')

            # Use Active Storage directly with customer
            customer.documents.attach(
              io: file_io,
              filename: filename,
              content_type: content_type
            )

            Rails.logger.info "Document attached successfully for customer #{customer.id}: #{document_data[:document_type]}"
          end
        end

      rescue => e
        Rails.logger.error "Error processing document for customer #{customer.id}: #{e.message}"
        # Don't re-raise the error, just log it and continue
      end
    end
  end

  # Helper methods for life insurance
  def create_life_insurance_nominee(policy, nominee_data)
    LifeInsuranceNominee.create!(
      life_insurance: policy,
      nominee_name: nominee_data[:nominee_name],
      relationship: nominee_data[:relationship],
      age: nominee_data[:age],
      share_percentage: nominee_data[:share_percentage] || 100.0
    )
  rescue => e
    Rails.logger.error "Error creating nominee: #{e.message}"
  end

  def create_life_insurance_bank_details(policy, bank_data)
    LifeInsuranceBankDetail.create!(
      life_insurance: policy,
      bank_name: bank_data[:bank_name],
      account_type: bank_data[:account_type],
      account_number: bank_data[:account_number],
      ifsc_code: bank_data[:ifsc_code],
      account_holder_name: bank_data[:account_holder_name]
    )
  rescue => e
    Rails.logger.error "Error creating bank details: #{e.message}"
  end

  def handle_life_insurance_document_uploads(policy, documents_data)
    documents_data.each_with_index do |doc_data, index|
      next if doc_data[:document_file].blank?

      begin
        # Decode base64 file
        decoded_file = Base64.decode64(doc_data[:document_file])

        # Create filename
        filename = "life_insurance_#{policy.id}_#{doc_data[:document_type]}_#{index + 1}.pdf"

        # Create a StringIO object for Active Storage
        file_io = StringIO.new(decoded_file)
        file_io.set_encoding('BINARY')

        # Create the document record
        document = LifeInsuranceDocument.create!(
          life_insurance: policy,
          document_type: doc_data[:document_type],
          document_name: filename
        )

        # Attach the file to the document record
        document.document.attach(
          io: file_io,
          filename: filename,
          content_type: 'application/pdf'
        )

        Rails.logger.info "Life insurance document uploaded successfully: #{filename}"
      rescue => e
        Rails.logger.error "Error processing life insurance document #{index}: #{e.message}"
      end
    end
  end

  def handle_motor_insurance_document_uploads(policy, documents_data)
    documents_data.each_with_index do |doc_data, index|
      next if doc_data[:document_file].blank?

      begin
        # Handle base64 document data
        if doc_data[:document_file].is_a?(String) && doc_data[:document_file].start_with?('data:')
          # Handle base64 encoded file with mime type
          data_match = doc_data[:document_file].match(/^data:([^;]+);base64,(.+)$/)
          if data_match
            content_type = data_match[1]
            base64_data = data_match[2]
            decoded_file = Base64.decode64(base64_data)
          else
            # Fallback: treat as plain base64 PDF
            content_type = 'application/pdf'
            decoded_file = Base64.decode64(doc_data[:document_file])
          end
        else
          # Assume plain base64 string
          content_type = 'application/pdf'
          decoded_file = Base64.decode64(doc_data[:document_file])
        end

        # Determine file extension based on content type
        extension = case content_type
                   when /image\/jpeg/ then '.jpg'
                   when /image\/png/ then '.png'
                   when /application\/pdf/ then '.pdf'
                   else '.pdf'
                   end

        # Create filename
        filename = "motor_insurance_#{policy.id}_#{doc_data[:document_type]}_#{index + 1}#{extension}"

        # Create a StringIO object for Active Storage
        file_io = StringIO.new(decoded_file)
        file_io.set_encoding('BINARY')

        # Attach the document directly to the motor insurance policy using Active Storage
        policy.documents.attach(
          io: file_io,
          filename: filename,
          content_type: content_type,
          metadata: {
            document_type: doc_data[:document_type],
            uploaded_by: 'agent',
            uploaded_at: Time.current.iso8601
          }
        )

        Rails.logger.info "Motor insurance document uploaded successfully: #{filename}"
      rescue => e
        Rails.logger.error "Error processing motor insurance document #{index}: #{e.message}"
      end
    end
  end

  # Helper method for commission statistics
  def get_commission_statistics(agent, period_filter = nil, policy_type_filter = nil)
    base_query = CommissionPayout.where(payout_to: 'sub_agent')

    # Filter by agent if sub_agent
    if is_sub_agent?(agent)
      health_policy_ids = HealthInsurance.where(sub_agent_id: agent.id).pluck(:id)
      life_policy_ids = LifeInsurance.where(sub_agent_id: agent.id).pluck(:id)

      base_query = base_query.where(
        "(policy_type = 'health' AND policy_id IN (?)) OR (policy_type = 'life' AND policy_id IN (?))",
        health_policy_ids.any? ? health_policy_ids : [0],
        life_policy_ids.any? ? life_policy_ids : [0]
      )
    end

    # Apply filters
    case period_filter
    when 'this_month'
      base_query = base_query.where(payout_date: Date.current.beginning_of_month..Date.current.end_of_month)
    when 'last_month'
      base_query = base_query.where(payout_date: 1.month.ago.beginning_of_month..1.month.ago.end_of_month)
    when 'this_year'
      base_query = base_query.where(payout_date: Date.current.beginning_of_year..Date.current.end_of_year)
    end

    if policy_type_filter.present? && policy_type_filter != 'all'
      base_query = base_query.where(policy_type: policy_type_filter)
    end

    {
      total_commissions: base_query.count,
      total_amount: base_query.sum(:payout_amount),
      paid_amount: base_query.where(status: 'paid').sum(:payout_amount),
      pending_amount: base_query.where(status: 'pending').sum(:payout_amount),
      paid_count: base_query.where(status: 'paid').count,
      pending_count: base_query.where(status: 'pending').count,
      by_policy_type: {
        health: {
          count: base_query.where(policy_type: 'health').count,
          amount: base_query.where(policy_type: 'health').sum(:payout_amount)
        },
        life: {
          count: base_query.where(policy_type: 'life').count,
          amount: base_query.where(policy_type: 'life').sum(:payout_amount)
        },
        motor: {
          count: base_query.where(policy_type: 'motor').count,
          amount: base_query.where(policy_type: 'motor').sum(:payout_amount)
        }
      }
    }
  end

  # Helper method to safely check user type Dr WISE User and SubAgent models
  def get_user_type(user)
    if user.is_a?(User)
      user.user_type
    elsif user.is_a?(SubAgent)
      'sub_agent'
    else
      'unknown'
    end
  end

  def is_admin?(user)
    user.is_a?(User) && user.user_type == 'admin'
  end

  def is_sub_agent?(user)
    # Check if user is a SubAgent or if there's a matching SubAgent by email/mobile
    return true if user.is_a?(SubAgent)
    return true if user.is_a?(User) && user.user_type == 'sub_agent'

    # Check if there's a SubAgent with matching email or mobile
    if user.is_a?(User)
      SubAgent.exists?(email: user.email) ||
      SubAgent.exists?(mobile: user.mobile) ||
      SubAgent.where('mobile LIKE ?', "%#{user.mobile.gsub(/[^\d]/, '')}%").exists?
    else
      false
    end
  end

  def is_affiliate?(user)
    # Additional check for users who should be treated as affiliates
    return false unless user.is_a?(User)

    # Check if user's role indicates affiliate or if they match SubAgent records
    user.user_type == 'affiliate' ||
    (user.user_type == 'customer' && SubAgent.exists?(email: user.email)) ||
    (user.user_type == 'customer' && SubAgent.exists?(mobile: user.mobile))
  end

  def create_user_for_customer(customer, password)
    begin
      # Get customer role
      customer_role = Role.find_by(name: 'customer')

      # Create user account for customer
      user = User.new(
        first_name: customer.first_name || 'Customer',
        last_name: customer.last_name || 'User',
        email: customer.email,
        password: password,
        password_confirmation: password,
        mobile: customer.mobile,
        user_type: 'customer',
        role: customer_role,
        role_id: customer_role&.id || 2,
        role_name: 'customer',
        status: true
      )

      if user.save(validate: false)
        Rails.logger.info "User account created successfully for customer #{customer.id}"
        {
          created: true,
          user_id: user.id,
          email: user.email,
          message: 'User account created successfully. Customer can now login with email and password.'
        }
      else
        Rails.logger.error "Failed to create user account for customer #{customer.id}: #{user.errors.full_messages}"
        {
          created: false,
          error: 'Failed to create user account',
          details: user.errors.full_messages,
          message: 'Customer created but user account creation failed. Customer cannot login yet.'
        }
      end
    rescue => e
      Rails.logger.error "Error creating user account for customer #{customer.id}: #{e.message}"
      {
        created: false,
        error: 'User account creation error',
        details: e.message,
        message: 'Customer created but user account creation failed. Customer cannot login yet.'
      }
    end
  end

  def generate_secure_password
    # Generate a secure password with uppercase, lowercase, numbers, and special characters
    charset = ('A'..'Z').to_a + ('a'..'z').to_a + (0..9).to_a + ['@', '$', '!', '%', '*', '?', '&']

    # Ensure at least one of each required character type
    password = []
    password << ('A'..'Z').to_a.sample  # Uppercase
    password << ('a'..'z').to_a.sample  # Lowercase
    password << (0..9).to_a.sample.to_s # Number
    password << ['@', '$', '!', '%', '*', '?', '&'].sample # Special char

    # Fill remaining characters randomly
    (8..12).to_a.sample.times do
      password << charset.sample.to_s
    end

    password.shuffle.join
  end

  # Optimized dashboard statistics helper methods

  def get_optimized_admin_stats
    # Use simple direct queries without complex aggregations
    current_month_start = Date.current.beginning_of_month
    current_month_end = Date.current.end_of_month

    # Basic counts
    health_count = HealthInsurance.count
    life_count = LifeInsurance.count
    motor_count = begin
      MotorInsurance.count
    rescue
      0
    end

    total_policies = health_count + life_count + motor_count

    # Basic sums
    health_premium = HealthInsurance.sum(:total_premium) || 0
    life_premium = LifeInsurance.sum(:total_premium) || 0
    motor_premium = begin
      MotorInsurance.sum(:total_premium) || 0
    rescue
      0
    end

    health_sum = HealthInsurance.sum(:sum_insured) || 0
    life_sum = LifeInsurance.sum(:sum_insured) || 0
    motor_sum = begin
      MotorInsurance.sum(:sum_insured) || 0
    rescue
      0
    end

    health_commission = HealthInsurance.sum(:commission_amount) || 0
    life_commission = LifeInsurance.sum(:commission_amount) || 0

    # Monthly counts
    monthly_health = HealthInsurance.where(created_at: current_month_start..current_month_end).count
    monthly_life = LifeInsurance.where(created_at: current_month_start..current_month_end).count
    monthly_health_premium = HealthInsurance.where(created_at: current_month_start..current_month_end).sum(:total_premium) || 0
    monthly_life_premium = LifeInsurance.where(created_at: current_month_start..current_month_end).sum(:total_premium) || 0

    # Customer counts
    total_customers = Customer.count
    active_customers = Customer.where(status: true).count
    monthly_customers = Customer.where(created_at: current_month_start..current_month_end).count

    # Renewal and expiry data
    thirty_days_from_now = Date.current + 30.days
    renewal_due = HealthInsurance.where('policy_end_date BETWEEN ? AND ?', Date.current, thirty_days_from_now).count +
                  LifeInsurance.where('policy_end_date BETWEEN ? AND ?', Date.current, thirty_days_from_now).count

    expired_policies = HealthInsurance.where('policy_end_date < ?', Date.current).count +
                      LifeInsurance.where('policy_end_date < ?', Date.current).count

    {
      customers_count: total_customers,
      active_customers: active_customers,
      inactive_customers: total_customers - active_customers,
      health_count: health_count,
      life_count: life_count,
      motor_count: motor_count,
      total_policies: total_policies,
      total_premium: health_premium + life_premium + motor_premium,
      total_sum_insured: health_sum + life_sum + motor_sum,
      total_commission: health_commission + life_commission,
      monthly_policies: monthly_health + monthly_life,
      monthly_premium: monthly_health_premium + monthly_life_premium,
      new_customers_month: monthly_customers,
      renewal_due: renewal_due,
      expired_policies: expired_policies,
      health_percentage: total_policies > 0 ? ((health_count.to_f / total_policies) * 100).round(2) : 0,
      life_percentage: total_policies > 0 ? ((life_count.to_f / total_policies) * 100).round(2) : 0,
      motor_percentage: total_policies > 0 ? ((motor_count.to_f / total_policies) * 100).round(2) : 0
    }
  end

  def get_optimized_sub_agent_stats(agent)
    current_month_start = Date.current.beginning_of_month
    current_month_end = Date.current.end_of_month

    # Use simple queries like the original method
    health_policies = HealthInsurance.where(sub_agent_id: agent.id)
    life_policies = LifeInsurance.where(sub_agent_id: agent.id)
    motor_policies = MotorInsurance.where(sub_agent_id: agent.id)

    # Get counts
    health_count = health_policies.count
    life_count = life_policies.count
    motor_count = motor_policies.count
    total_policies = health_count + life_count + motor_count

    # Get sums
    health_premium = health_policies.sum(:total_premium) || 0
    life_premium = life_policies.sum(:total_premium) || 0
    motor_premium = motor_policies.sum(:total_premium) || 0
    health_sum_insured = health_policies.sum(:sum_insured) || 0
    life_sum_insured = life_policies.sum(:sum_insured) || 0
    motor_sum_insured = motor_policies.sum(:sum_insured) || 0

    # Commission - sourced from CommissionPayout records (matches admin web view)
    payout_base = CommissionPayout.where(payout_to: ['sub_agent', 'affiliate'])
      .joins("LEFT JOIN health_insurances ON commission_payouts.policy_type = 'health' AND commission_payouts.policy_id = health_insurances.id
              LEFT JOIN life_insurances ON commission_payouts.policy_type = 'life' AND commission_payouts.policy_id = life_insurances.id
              LEFT JOIN motor_insurances ON commission_payouts.policy_type = 'motor' AND commission_payouts.policy_id = motor_insurances.id")
      .where("(commission_payouts.policy_type = 'health' AND health_insurances.sub_agent_id = ?) OR
              (commission_payouts.policy_type = 'life' AND life_insurances.sub_agent_id = ?) OR
              (commission_payouts.policy_type = 'motor' AND motor_insurances.sub_agent_id = ?)",
              agent.id, agent.id, agent.id)

    all_payouts = payout_base.to_a
    h_map = HealthInsurance.where(id: all_payouts.select { |p| p.policy_type == 'health' }.map(&:policy_id)).index_by(&:id)
    l_map = LifeInsurance.where(id: all_payouts.select { |p| p.policy_type == 'life' }.map(&:policy_id)).index_by(&:id)
    m_map = begin; MotorInsurance.where(id: all_payouts.select { |p| p.policy_type == 'motor' }.map(&:policy_id)).index_by(&:id); rescue; {}; end

    health_commission = 0.0; life_commission = 0.0; motor_commission = 0.0
    all_payouts.each do |payout|
      case payout.policy_type
      when 'health'
        g = h_map[payout.policy_id]&.sub_agent_commission_amount.to_f
        health_commission += g.zero? ? payout.payout_amount.to_f : g
      when 'life'
        g = l_map[payout.policy_id]&.sub_agent_commission_amount.to_f
        life_commission += g.zero? ? payout.payout_amount.to_f : g
      when 'motor'
        g = m_map[payout.policy_id]&.try(:sub_agent_commission_amount).to_f
        motor_commission += g.zero? ? payout.payout_amount.to_f : g
      end
    end
    total_commission = health_commission + life_commission + motor_commission

    # Monthly commission from payouts in current month
    monthly_payouts = all_payouts.select { |p| p.payout_date && p.payout_date >= current_month_start && p.payout_date <= current_month_end }
    monthly_commission = monthly_payouts.sum do |payout|
      case payout.policy_type
      when 'health'
        g = h_map[payout.policy_id]&.sub_agent_commission_amount.to_f
        g.zero? ? payout.payout_amount.to_f : g
      when 'life'
        g = l_map[payout.policy_id]&.sub_agent_commission_amount.to_f
        g.zero? ? payout.payout_amount.to_f : g
      when 'motor'
        g = m_map[payout.policy_id]&.try(:sub_agent_commission_amount).to_f
        g.zero? ? payout.payout_amount.to_f : g
      else; 0.0
      end
    end

    # Monthly data
    monthly_health_count = health_policies.where(created_at: current_month_start..current_month_end).count
    monthly_life_count = life_policies.where(created_at: current_month_start..current_month_end).count
    monthly_motor_count = motor_policies.where(created_at: current_month_start..current_month_end).count
    monthly_health_premium = health_policies.where(created_at: current_month_start..current_month_end).sum(:total_premium) || 0
    monthly_life_premium = life_policies.where(created_at: current_month_start..current_month_end).sum(:total_premium) || 0
    monthly_motor_premium = motor_policies.where(created_at: current_month_start..current_month_end).sum(:total_premium) || 0

    # Get unique customer IDs for real-time count
    customer_ids = (health_policies.pluck(:customer_id) + life_policies.pluck(:customer_id) + motor_policies.pluck(:customer_id)).uniq
    monthly_customer_ids = (health_policies.where(created_at: current_month_start..current_month_end).pluck(:customer_id) +
                           life_policies.where(created_at: current_month_start..current_month_end).pluck(:customer_id) +
                           motor_policies.where(created_at: current_month_start..current_month_end).pluck(:customer_id)).uniq

    # Calculate total customers assigned to this agent (including those without policies)
    total_customers_count = Customer.where(sub_agent_id: agent.id).active.count

    # Calculate target achievement
    monthly_target = 50000.0
    target_achievement = monthly_commission > 0 ? ((monthly_commission / monthly_target) * 100).round(2) : 0

    {
      customers_count: total_customers_count,
      health_count: health_count,
      life_count: life_count,
      motor_count: motor_count,
      total_policies: total_policies,
      total_premium: (health_premium + life_premium + motor_premium).round(2),
      total_sum_insured: (health_sum_insured + life_sum_insured + motor_sum_insured).round(2),
      commission_earned: total_commission.round(2),
      monthly_policies: monthly_health_count + monthly_life_count + monthly_motor_count,
      monthly_premium: (monthly_health_premium + monthly_life_premium + monthly_motor_premium).round(2),
      monthly_customers: Customer.where(sub_agent_id: agent.id).where(created_at: current_month_start..current_month_end).active.count,
      commission_this_month: monthly_commission.round(2),
      target_achievement: target_achievement,
      conversion_rate: customer_ids.count > 0 && total_policies > 0 ? ((total_policies.to_f / customer_ids.count) * 100).round(2) : 0,
      health_percentage: total_policies > 0 ? ((health_count.to_f / total_policies) * 100).round(2) : 0,
      life_percentage: total_policies > 0 ? ((life_count.to_f / total_policies) * 100).round(2) : 0,
      motor_percentage: total_policies > 0 ? ((motor_count.to_f / total_policies) * 100).round(2) : 0
    }
  end

  # GET /api/v1/mobile/agent/policies/general
  def general_policies
    page     = (params[:page]     || 1).to_i
    per_page = (params[:per_page] || 20).to_i
    agent    = current_user

    policies = if is_admin?(agent)
                 OtherInsurance.all
               elsif agent.is_a?(SubAgent)
                 OtherInsurance.where(sub_agent_id: agent.id)
               else
                 sub_agent = SubAgent.find_by(email: agent.email)
                 sub_agent ? OtherInsurance.where(sub_agent_id: sub_agent.id) : OtherInsurance.none
               end

    policies = policies.includes(:customer).order(created_at: :desc)

    total = policies.count
    paged = policies.page(page).per(per_page)

    render json: {
      success: true,
      data: {
        policies: paged.map { |p| format_general_policy(p) },
        pagination: {
          current_page: page,
          per_page: per_page,
          total_policies: total,
          total_pages: (total.to_f / per_page).ceil
        }
      }
    }
  end

  # POST /api/v1/mobile/agent/policies/general
  def add_general_policy
    policy_params = params.permit(
      :customer_id, :policy_holder, :plan_name, :policy_number,
      :insurance_company_name, :insurance_type, :policy_type,
      :policy_start_date, :policy_end_date, :policy_booking_date,
      :sum_insured, :net_premium, :gst_percentage, :total_premium,
      :payment_mode, :coverage_type, :description
    )

    return render json: { success: false, message: 'customer_id is required' }, status: :unprocessable_entity if policy_params[:customer_id].blank?
    return render json: { success: false, message: 'policy_number is required' }, status: :unprocessable_entity if policy_params[:policy_number].blank?
    return render json: { success: false, message: 'insurance_type is required' }, status: :unprocessable_entity if policy_params[:insurance_type].blank?

    customer = Customer.find_by(id: policy_params[:customer_id])
    return render json: { success: false, message: 'Customer not found' }, status: :not_found unless customer

    if OtherInsurance.exists?(policy_number: policy_params[:policy_number])
      return render json: { success: false, message: 'Policy number already exists' }, status: :unprocessable_entity
    end

    sub_agent_id = current_user.is_a?(SubAgent) ? current_user.id : SubAgent.find_by(email: current_user.email)&.id

    calculated_total = if policy_params[:total_premium].present?
                         policy_params[:total_premium].to_f
                       else
                         net = policy_params[:net_premium].to_f
                         gst = policy_params[:gst_percentage]&.to_f || 18.0
                         net + (net * gst / 100.0)
                       end

    policy = OtherInsurance.new(
      customer_id: policy_params[:customer_id],
      sub_agent_id: sub_agent_id,
      policy_holder: policy_params[:policy_holder],
      plan_name: policy_params[:plan_name],
      insurance_company_name: policy_params[:insurance_company_name],
      insurance_type: policy_params[:insurance_type],
      policy_type: policy_params[:policy_type] == 'renewal' ? 'Renewal' : 'New',
      policy_number: policy_params[:policy_number],
      policy_booking_date: parse_date(policy_params[:policy_booking_date]) || Date.current,
      policy_start_date: parse_date(policy_params[:policy_start_date]),
      policy_end_date: parse_date(policy_params[:policy_end_date]),
      sum_insured: policy_params[:sum_insured],
      net_premium: policy_params[:net_premium],
      gst_percentage: policy_params[:gst_percentage] || 18.0,
      total_premium: calculated_total,
      payment_mode: policy_params[:payment_mode] || 'Annual',
      is_agent_added: true,
      is_admin_added: false
    )

    if policy.save
      render json: {
        success: true,
        message: 'General insurance policy created successfully',
        data: format_general_policy(policy)
      }, status: :created
    else
      render json: {
        success: false,
        message: 'Failed to create policy',
        errors: policy.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def format_general_policy(policy)
    {
      id: policy.id,
      insurance_type: policy.insurance_type,
      policy_number: policy.policy_number,
      plan_name: policy.plan_name,
      policy_holder: policy.policy_holder,
      insurance_company: policy.insurance_company_name,
      policy_type: policy.policy_type,
      start_date: policy.policy_start_date&.strftime('%Y-%m-%d'),
      end_date: policy.policy_end_date&.strftime('%Y-%m-%d'),
      net_premium: format_indian_amount(policy.net_premium),
      total_premium: format_indian_amount(policy.total_premium),
      sum_insured: format_indian_amount(policy.sum_insured),
      payment_mode: policy.payment_mode,
      status: policy.active? ? 'Active' : 'Expired',
      customer_name: policy.customer&.display_name,
      created_at: policy.created_at&.strftime('%Y-%m-%d %H:%M:%S')
    }
  end

  def get_optimized_agent_stats(agent)
    # Get agent policies using existing method but optimize queries
    agent_health_policies, agent_life_policies, agent_motor_policies, agent_customer_ids = get_agent_policies(agent)

    # Also include customers added by the agent through mobile API
    agent_added_customers = Customer.where("added_by LIKE ?", "%agent_mobile_api_#{agent.id}%")
    all_agent_customers = Customer.where(id: agent_customer_ids).or(agent_added_customers)

    # Current month data
    current_month_start = Date.current.beginning_of_month
    current_month_end = Date.current.end_of_month

    monthly_health = agent_health_policies.where(created_at: current_month_start..current_month_end)
    monthly_life = agent_life_policies.where(created_at: current_month_start..current_month_end)
    monthly_motor = agent_motor_policies.where(created_at: current_month_start..current_month_end)

    total_policies = agent_health_policies.count + agent_life_policies.count + agent_motor_policies.count

    {
      customers_count: all_agent_customers.active.count,
      health_count: agent_health_policies.count,
      life_count: agent_life_policies.count,
      motor_count: agent_motor_policies.count,
      total_policies: total_policies,
      total_premium: agent_health_policies.sum(:total_premium) + agent_life_policies.sum(:total_premium) + agent_motor_policies.sum(:total_premium),
      commission_earned: (agent_health_policies.sum(:sub_agent_commission_amount) + agent_life_policies.sum(:sub_agent_commission_amount) + agent_motor_policies.sum(:sub_agent_commission_amount)),
      monthly_policies: monthly_health.count + monthly_life.count + monthly_motor.count,
      monthly_premium: monthly_health.sum(:total_premium) + monthly_life.sum(:total_premium) + monthly_motor.sum(:total_premium),
      health_percentage: total_policies > 0 ? ((agent_health_policies.count.to_f / total_policies) * 100).round(2) : 0,
      life_percentage: total_policies > 0 ? ((agent_life_policies.count.to_f / total_policies) * 100).round(2) : 0,
      motor_percentage: total_policies > 0 ? ((agent_motor_policies.count.to_f / total_policies) * 100).round(2) : 0
    }
  end
end