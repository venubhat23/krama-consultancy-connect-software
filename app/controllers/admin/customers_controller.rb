class Admin::CustomersController < Admin::ApplicationController
  include LocationData
  include ConfigurablePagination
  before_action :set_customer, only: [:show, :edit, :update, :destroy, :associations_summary, :policy_chart, :trace_commission, :product_selection, :deactivate, :activate, :get_policies, :family_members, :affiliate_info]
  skip_before_action :ensure_admin, only: [:search_sub_agents]
  skip_before_action :authenticate_user!, only: [:search_sub_agents]
  skip_load_and_authorize_resource only: [:search_sub_agents]
  skip_before_action :verify_authenticity_token, only: [:trace_commission], if: :api_request?

  # GET /admin/customers
  def index
    # Optimize query by selecting only needed columns for index page
    index_columns = %w[
      id first_name middle_name last_name company_name customer_type mobile
      email status deactivated created_at sub_agent_id sub_agent lead_id
    ]

    has_counter_cache = Customer.column_names.include?('policies_count')
    index_columns << 'policies_count' if has_counter_cache

    # Start with base query - don't use select when search is present to avoid PostgreSQL count issues
    if params[:search].present? && params[:search].strip.length >= 2
      @customers = Customer.with_attached_profile_image
      search_term = params[:search].strip
      @customers = @customers.partial_search(search_term)
    elsif params[:search].present? && params[:search].strip.length == 1
      @customers = Customer.select(index_columns.join(', ')).with_attached_profile_image.none
    else
      # Use optimized select for faster loading when not searching
      @customers = Customer.select(index_columns.join(', ')).with_attached_profile_image
    end

    # Lead ID search functionality - search by full lead ID or last 4 digits
    if params[:lead_id_search].present?
      lead_id_term = params[:lead_id_search].strip
      if lead_id_term.length >= 4
        # Search for exact match (case insensitive) or partial match containing the term
        @customers = @customers.where("lead_id ILIKE ? OR lead_id ILIKE ?", lead_id_term, "%#{lead_id_term}%")
      elsif lead_id_term.length > 0
        # Return empty result if lead ID search term is too short
        @customers = @customers.none
      end
    end

    # Filter by customer type
    if params[:customer_type].present?
      @customers = @customers.where(customer_type: params[:customer_type])
    end

    # Filter by status
    case params[:status]
    when 'active'
      @customers = @customers.where(status: true)
    when 'inactive'
      @customers = @customers.where(status: false)
    end

    # Get total count before pagination for display purposes
    # Use the same scope as the main query for accurate count
    count_scope = Customer.all

    # Apply same filters as main query for accurate count
    if params[:search].present?
      search_term = params[:search].strip
      if search_term.length >= 2
        count_scope = count_scope.partial_search(search_term)
      elsif search_term.length == 1
        count_scope = count_scope.none
      end
    end

    # Apply lead ID search filter to count scope
    if params[:lead_id_search].present?
      lead_id_term = params[:lead_id_search].strip
      if lead_id_term.length >= 4
        count_scope = count_scope.where("lead_id ILIKE ? OR lead_id ILIKE ?", lead_id_term, "%#{lead_id_term}%")
      elsif lead_id_term.length > 0
        count_scope = count_scope.none
      end
    end

    if params[:customer_type].present?
      count_scope = count_scope.where(customer_type: params[:customer_type])
    end

    case params[:status]
    when 'active'
      count_scope = count_scope.where(status: true)
    when 'inactive'
      count_scope = count_scope.where(status: false)
    end

    @total_filtered_count = count_scope.count

    # Order and paginate using configurable pagination
    # Pass the pre-calculated count to avoid PostgreSQL issues with select() queries
    @customers = paginate_records(@customers.includes(:affiliate, :documents).order(created_at: :desc), @total_filtered_count)

    # Calculate statistics
    # Create a separate scope for statistics to avoid pg_search GROUP BY issues
    stats_scope = Customer.all

    # Apply filters for stats
    if params[:search].present? && params[:search].strip.length >= 2
      stats_scope = stats_scope.partial_search(params[:search].strip)
    end

    # Apply lead ID search to stats scope
    if params[:lead_id_search].present? && params[:lead_id_search].strip.length >= 4
      lead_id_term = params[:lead_id_search].strip
      stats_scope = stats_scope.where("lead_id ILIKE ? OR lead_id ILIKE ?", lead_id_term, "%#{lead_id_term}%")
    end

    if params[:customer_type].present?
      stats_scope = stats_scope.where(customer_type: params[:customer_type])
    end

    case params[:status]
    when 'active'
      stats_scope = stats_scope.where(status: true)
    when 'inactive'
      stats_scope = stats_scope.where(status: false)
    end

    # Calculate filtered stats using simple queries to avoid GROUP BY issues
    @stats = if params[:search].present? && params[:search].strip.length >= 4
      # When search is active, use simpler aggregation
      {
        total_customers: stats_scope.count,
        active_customers: stats_scope.where(status: true).count,
        individual_customers: stats_scope.where(customer_type: 'individual').count,
        corporate_customers: stats_scope.where(customer_type: 'corporate').count
      }
    else
      # When no search, can use GROUP BY safely
      stats_data = stats_scope.group(:customer_type, :status).count
      stats_data.each_with_object(Hash.new(0)) do |(key, count), stats|
        customer_type, status = key

        stats[:total_customers] += count
        stats[:active_customers] += count if status == true
        stats[:individual_customers] += count if customer_type == 'individual'
        stats[:corporate_customers] += count if customer_type == 'corporate'
      end.tap do |stats|
        stats[:total_customers] = stats_scope.count if stats[:total_customers] == 0
      end
    end

    @total_customers = @stats[:total_customers]
    @active_customers = @stats[:active_customers]
    @individual_customers = @stats[:individual_customers]
    @corporate_customers = @stats[:corporate_customers]

    # Handle AJAX requests
    respond_to do |format|
      format.html # Regular HTML request
      format.json { render json: { customers: @customers, stats: @stats } }
    end
  end

  # GET /admin/customers/1
  def show
    # Eager load all associations to avoid N+1 queries
    @customer = Customer.includes(
      :family_members,
      { health_insurances: :renewal_policy },
      { life_insurances: :renewal_policy },
      { other_insurances: :renewal_policy },
      :motor_insurances,
      :uploaded_documents
    ).find(params[:id])

    @family_members = @customer.family_members.order(:created_at)
    @uploaded_documents = @customer.uploaded_documents.order(:created_at)

    # Find all associated leads for this customer
    @associated_leads = Lead.where(converted_customer_id: @customer.id)
                           .or(Lead.where(lead_id: @customer.lead_id))
                           .order(:created_at)

    # Keep the original @lead for backward compatibility
    @lead = @associated_leads.first

    # Gather all policies from different insurance types - using preloaded associations
    @all_policies = []

    policy_status = lambda do |policy|
      if policy.active?
        'Active'
      elsif (policy.respond_to?(:has_been_renewed?) && policy.has_been_renewed?) ||
            (policy.respond_to?(:is_renewed) && policy.is_renewed == true)
        'Renewed'
      else
        'Expired'
      end
    end

    @customer.health_insurances.each do |policy|
      @all_policies << {
        type: 'Health Insurance',
        policy: policy,
        policy_number: policy.policy_number,
        company_name: policy.insurance_company_name,
        premium: policy.total_premium,
        start_date: policy.policy_start_date,
        end_date: policy.policy_end_date,
        status: policy_status.call(policy),
        created_at: policy.created_at
      }
    end

    @customer.life_insurances.each do |policy|
      @all_policies << {
        type: 'Life Insurance',
        policy: policy,
        policy_number: policy.policy_number,
        company_name: policy.insurance_company_name,
        premium: policy.total_premium,
        start_date: policy.policy_start_date,
        end_date: policy.policy_end_date,
        status: policy_status.call(policy),
        created_at: policy.created_at
      }
    end

    @customer.motor_insurances.each do |policy|
      @all_policies << {
        type: 'Motor Insurance',
        policy: policy,
        policy_number: policy.policy_number,
        company_name: policy.insurance_company_name,
        premium: policy.total_premium,
        start_date: policy.policy_start_date,
        end_date: policy.policy_end_date,
        status: policy_status.call(policy),
        created_at: policy.created_at
      }
    end

    @customer.other_insurances.each do |policy|
      @all_policies << {
        type: 'Other Insurance',
        policy: policy,
        policy_number: policy.policy_number,
        company_name: policy.insurance_company_name,
        premium: policy.total_premium,
        start_date: policy.policy_start_date,
        end_date: policy.policy_end_date,
        status: policy_status.call(policy),
        created_at: policy.created_at
      }
    end

    @all_policies.sort_by! { |p| p[:created_at] }.reverse!

    # --- Per-type grouped policies (exclude Renewed — those belong in Past Policy only) ---
    @health_policies  = @all_policies.select { |p| p[:type] == 'Health Insurance' && p[:status] != 'Renewed' }
    @life_policies    = @all_policies.select { |p| p[:type] == 'Life Insurance'   && p[:status] != 'Renewed' }
    @motor_policies   = @all_policies.select { |p| p[:type] == 'Motor Insurance'  && p[:status] != 'Renewed' }
    @other_policies   = @all_policies.select { |p| p[:type] == 'Other Insurance'  && p[:status] != 'Renewed' }

    # --- Expired: end_date passed AND policy has NOT been renewed ---
    @expired_policies = @all_policies.select { |p| p[:status] == 'Expired' }

    # --- Past: end_date passed AND policy WAS renewed ---
    @past_policies = @all_policies.select { |p| p[:status] == 'Renewed' }

    # --- Upcoming Renewal: active policies whose end_date is within 60 days ---
    @upcoming_renewal_policies = @all_policies.select do |p|
      next false unless p[:status] == 'Active' && p[:end_date]
      days = (p[:end_date] - Date.current).to_i
      days >= 0 && days <= 60
    end

    # --- Upcoming Installments: next installment due within 60 days for installment-mode active policies ---
    installment_modes = ['Monthly', 'Quarterly', 'Half Yearly', 'Half-Yearly', 'Semi-Annual']
    installment_intervals = { 'Monthly' => 1, 'Quarterly' => 3, 'Half Yearly' => 6, 'Half-Yearly' => 6, 'Semi-Annual' => 6 }

    @upcoming_installment_policies = []
    @all_policies.each do |p|
      next unless p[:status] == 'Active'
      obj = p[:policy]
      next unless obj.respond_to?(:payment_mode) && installment_modes.include?(obj.payment_mode)
      next unless p[:start_date]

      months = installment_intervals[obj.payment_mode] || 1
      # Find the next installment date from start_date
      today = Date.current
      n = 0
      loop do
        n += 1
        next_due = p[:start_date] >> (n * months)
        break if next_due > (today + 60.days)
        if next_due >= today && next_due <= (today + 60.days)
          @upcoming_installment_policies << p.merge(next_installment_date: next_due)
          break
        end
      end
    end

    # Legacy counts for backward compatibility
    @active_policies_count        = @all_policies.count { |p| p[:status] == 'Active' }
    @renewed_policies_count       = @all_policies.count { |p| p[:status] == 'Renewed' }
    @expired_policies_count       = @expired_policies.count
    @past_policies_count          = @past_policies.count
    @upcoming_installments_count  = @upcoming_installment_policies.count

    @policies = @all_policies
  end

  # GET /admin/customers/:id/policy_chart
  def policy_chart
    # Get all policy types and their status for this customer
    @policy_status = {
      'Health Insurance' => {
        exists: HealthInsurance.exists?(customer_id: @customer.id),
        count: HealthInsurance.where(customer_id: @customer.id).count,
        icon: 'bi-heart-pulse',
        color: 'info',
        policies: HealthInsurance.where(customer_id: @customer.id).includes(:customer)
      },
      'Life Insurance' => {
        exists: LifeInsurance.exists?(customer_id: @customer.id),
        count: LifeInsurance.where(customer_id: @customer.id).count,
        icon: 'bi-shield-check',
        color: 'primary',
        policies: LifeInsurance.where(customer_id: @customer.id).includes(:customer)
      },
      'Motor Insurance' => {
        exists: MotorInsurance.exists?(customer_id: @customer.id),
        count: MotorInsurance.where(customer_id: @customer.id).count,
        icon: 'bi-car-front',
        color: 'warning',
        policies: MotorInsurance.where(customer_id: @customer.id).includes(:customer)
      },
      'Other Insurance' => {
        exists: defined?(OtherInsurance) && OtherInsurance.exists?(customer_id: @customer.id),
        count: defined?(OtherInsurance) ? OtherInsurance.where(customer_id: @customer.id).count : 0,
        icon: 'bi-grid-3x3',
        color: 'secondary',
        policies: defined?(OtherInsurance) ? OtherInsurance.where(customer_id: @customer.id).includes(:customer) : []
      }
    }

    # Calculate totals
    @total_policies = @policy_status.values.sum { |policy| policy[:count] }
    @policy_types_with_coverage = @policy_status.count { |_, policy| policy[:exists] }
    @coverage_percentage = @policy_types_with_coverage > 0 ? (@policy_types_with_coverage.to_f / @policy_status.keys.count * 100).round(1) : 0
  end

  # GET /admin/customers/:id/trace_commission
  def trace_commission
    # Handle API requests for insurance policies
    if params[:type] && params[:insurance_type]
      type = params[:type] # 'drwise' or 'non-drwise'
      insurance_type = params[:insurance_type] # 'motor', 'life', 'health', 'motorinsurance', etc.

      Rails.logger.info "API Request - Type: #{type}, Insurance Type: #{insurance_type}, Customer: #{@customer&.id}"

      # Simple test mode for debugging
      if params[:test] == 'true'
        return render json: {
          success: true,
          message: "API is working",
          customer: @customer&.display_name,
          type: type,
          insurance_type: insurance_type,
          test: true
        }
      end

      begin
        case insurance_type.downcase
        when 'motor', 'motorinsurance'
          policies = fetch_motor_policies(@customer, type)
        when 'life', 'lifeinsurance'
          policies = fetch_life_policies(@customer, type)
        when 'health', 'healthinsurance'
          policies = fetch_health_policies(@customer, type)
        else
          return render json: { success: false, error: 'Invalid insurance type' }, status: 400
        end

        Rails.logger.info "Found #{policies.count} policies"

        return render json: {
          success: true,
          policies: policies,
          count: policies.count,
          insurance_type: insurance_type,
          customer_name: @customer.display_name
        }
      rescue => e
        Rails.logger.error "Error fetching #{insurance_type} insurance policies: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        return render json: {
          success: false,
          error: "Failed to load #{insurance_type} insurance policies",
          message: e.message,
          backtrace: Rails.env.development? ? e.backtrace.first(5) : nil
        }, status: 500
      end
    end
    # Get DrWise and Non-DrWise policies separately
    @drwise_policy_status = {}
    @non_drwise_policy_status = {}

    # Health Insurance - DrWise vs Non-DrWise
    health_drwise = HealthInsurance.where(customer_id: @customer.id, is_admin_added: true, is_customer_added: false, is_agent_added: false)
    health_non_drwise = HealthInsurance.where(customer_id: @customer.id).where(
      '(is_customer_added = ? AND is_admin_added = ? AND is_agent_added = ?) OR (is_agent_added = ? AND is_customer_added = ? AND is_admin_added = ?)',
      true, false, false, true, false, false
    )

    @drwise_policy_status['Health Insurance'] = {
      opted: health_drwise.exists?,
      count: health_drwise.count,
      icon: 'bi-heart-pulse',
      color: 'success',
      policies: health_drwise,
      total_premium: health_drwise.sum(:total_premium) || 0,
      latest_policy: health_drwise.order(:created_at).last
    }

    @non_drwise_policy_status['Health Insurance'] = {
      opted: health_non_drwise.exists?,
      count: health_non_drwise.count,
      icon: 'bi-heart-pulse',
      color: 'success',
      policies: health_non_drwise,
      total_premium: health_non_drwise.sum(:total_premium) || 0,
      latest_policy: health_non_drwise.order(:created_at).last
    }

    # Life Insurance - DrWise vs Non-DrWise
    life_drwise = LifeInsurance.where(customer_id: @customer.id, is_admin_added: true, is_customer_added: false, is_agent_added: false)
    life_non_drwise = LifeInsurance.where(customer_id: @customer.id).where(
      '(is_customer_added = ? AND is_admin_added = ? AND is_agent_added = ?) OR (is_agent_added = ? AND is_customer_added = ? AND is_admin_added = ?)',
      true, false, false, true, false, false
    )

    @drwise_policy_status['Life Insurance'] = {
      opted: life_drwise.exists?,
      count: life_drwise.count,
      icon: 'bi-shield-check',
      color: 'primary',
      policies: life_drwise,
      total_premium: life_drwise.sum(:total_premium) || 0,
      latest_policy: life_drwise.order(:created_at).last
    }

    @non_drwise_policy_status['Life Insurance'] = {
      opted: life_non_drwise.exists?,
      count: life_non_drwise.count,
      icon: 'bi-shield-check',
      color: 'primary',
      policies: life_non_drwise,
      total_premium: life_non_drwise.sum(:total_premium) || 0,
      latest_policy: life_non_drwise.order(:created_at).last
    }

    # Motor Insurance - DrWise vs Non-DrWise (if they have the admin/customer/agent added fields)
    if MotorInsurance.column_names.include?('is_admin_added')
      motor_drwise = MotorInsurance.where(customer_id: @customer.id, is_admin_added: true, is_customer_added: false, is_agent_added: false)
      motor_non_drwise = MotorInsurance.where(customer_id: @customer.id).where(
        '(is_customer_added = ? AND is_admin_added = ? AND is_agent_added = ?) OR (is_agent_added = ? AND is_customer_added = ? AND is_admin_added = ?)',
        true, false, false, true, false, false
      )
    else
      # For backwards compatibility, treat all motor insurance as non-drwise
      motor_drwise = MotorInsurance.none
      motor_non_drwise = MotorInsurance.where(customer_id: @customer.id)
    end

    @drwise_policy_status['Motor Insurance'] = {
      opted: motor_drwise.exists?,
      count: motor_drwise.count,
      icon: 'bi-car-front',
      color: 'warning',
      policies: motor_drwise,
      total_premium: motor_drwise.sum(:total_premium) || 0,
      latest_policy: motor_drwise.order(:created_at).last
    }

    @non_drwise_policy_status['Motor Insurance'] = {
      opted: motor_non_drwise.exists?,
      count: motor_non_drwise.count,
      icon: 'bi-car-front',
      color: 'warning',
      policies: motor_non_drwise,
      total_premium: motor_non_drwise.sum(:total_premium) || 0,
      latest_policy: motor_non_drwise.order(:created_at).last
    }

    # Keep original policy status for backwards compatibility
    @policy_status = {
      'Health Insurance' => {
        opted: HealthInsurance.exists?(customer_id: @customer.id),
        count: HealthInsurance.where(customer_id: @customer.id).count,
        icon: 'bi-heart-pulse',
        color: 'success',
        policies: HealthInsurance.where(customer_id: @customer.id),
        total_premium: HealthInsurance.where(customer_id: @customer.id).sum(:total_premium) || 0,
        latest_policy: HealthInsurance.where(customer_id: @customer.id).order(:created_at).last
      },
      'Life Insurance' => {
        opted: LifeInsurance.exists?(customer_id: @customer.id),
        count: LifeInsurance.where(customer_id: @customer.id).count,
        icon: 'bi-shield-check',
        color: 'primary',
        policies: LifeInsurance.where(customer_id: @customer.id),
        total_premium: LifeInsurance.where(customer_id: @customer.id).sum(:total_premium) || 0,
        latest_policy: LifeInsurance.where(customer_id: @customer.id).order(:created_at).last
      },
      'Motor Insurance' => {
        opted: MotorInsurance.exists?(customer_id: @customer.id),
        count: MotorInsurance.where(customer_id: @customer.id).count,
        icon: 'bi-car-front',
        color: 'warning',
        policies: MotorInsurance.where(customer_id: @customer.id),
        total_premium: MotorInsurance.where(customer_id: @customer.id).sum(:total_premium) || 0,
        latest_policy: MotorInsurance.where(customer_id: @customer.id).order(:created_at).last
      }
    }

    # Get comprehensive product status (handling cases where tables might not exist yet)
    @product_status = {}

    # Insurance Products
    @product_status['Life'] = @policy_status['Life Insurance'][:opted]
    @product_status['Health'] = @policy_status['Health Insurance'][:opted]
    @product_status['Motor'] = @policy_status['Motor Insurance'][:opted]
    @product_status['General'] = false # Placeholder for General Insurance
    @product_status['Travel Insurance'] = false # Placeholder for Travel Insurance

    # Initialize DrWise and Non-DrWise status for non-insurance products
    # Since these don't have actual admin/customer/agent flags yet, we'll use placeholder logic

    # Investment Products - DrWise vs Non-DrWise
    @drwise_product_status = {}
    @non_drwise_product_status = {}

    # Investment Products (check if tables exist)
    begin
      if @customer.respond_to?(:investments)
        # For now, randomly assign some as DrWise for demonstration
        # In real implementation, these would have is_admin_added flags
        mutual_funds = @customer.investments.where(investment_type: 'Mutual Fund')
        gold = @customer.investments.where(investment_type: 'Gold')
        nps = @customer.investments.where(investment_type: 'NPS')
        bonds = @customer.investments.where(investment_type: 'Bonds')

        @drwise_product_status['Mutual Fund'] = { opted: false, count: 0 }
        @non_drwise_product_status['Mutual Fund'] = { opted: mutual_funds.exists?, count: mutual_funds.count }

        @drwise_product_status['Gold'] = { opted: false, count: 0 }
        @non_drwise_product_status['Gold'] = { opted: gold.exists?, count: gold.count }

        @drwise_product_status['NPS'] = { opted: false, count: 0 }
        @non_drwise_product_status['NPS'] = { opted: nps.exists?, count: nps.count }

        @drwise_product_status['Bonds'] = { opted: false, count: 0 }
        @non_drwise_product_status['Bonds'] = { opted: bonds.exists?, count: bonds.count }
      else
        @drwise_product_status['Mutual Fund'] = { opted: false, count: 0 }
        @non_drwise_product_status['Mutual Fund'] = { opted: false, count: 0 }
        @drwise_product_status['Gold'] = { opted: false, count: 0 }
        @non_drwise_product_status['Gold'] = { opted: false, count: 0 }
        @drwise_product_status['NPS'] = { opted: false, count: 0 }
        @non_drwise_product_status['NPS'] = { opted: false, count: 0 }
        @drwise_product_status['Bonds'] = { opted: false, count: 0 }
        @non_drwise_product_status['Bonds'] = { opted: false, count: 0 }
      end
    rescue
      @drwise_product_status['Mutual Fund'] = { opted: false, count: 0 }
      @non_drwise_product_status['Mutual Fund'] = { opted: false, count: 0 }
      @drwise_product_status['Gold'] = { opted: false, count: 0 }
      @non_drwise_product_status['Gold'] = { opted: false, count: 0 }
      @drwise_product_status['NPS'] = { opted: false, count: 0 }
      @non_drwise_product_status['NPS'] = { opted: false, count: 0 }
      @drwise_product_status['Bonds'] = { opted: false, count: 0 }
      @non_drwise_product_status['Bonds'] = { opted: false, count: 0 }
    end

    # Loan Products - DrWise vs Non-DrWise
    begin
      if @customer.respond_to?(:loans)
        personal_loans = @customer.loans.where(loan_type: 'Personal')
        home_loans = @customer.loans.where(loan_type: 'Home')
        business_loans = @customer.loans.where(loan_type: 'Business')

        @drwise_product_status['Personal Loan'] = { opted: false, count: 0 }
        @non_drwise_product_status['Personal Loan'] = { opted: personal_loans.exists?, count: personal_loans.count }

        @drwise_product_status['Home Loan'] = { opted: false, count: 0 }
        @non_drwise_product_status['Home Loan'] = { opted: home_loans.exists?, count: home_loans.count }

        @drwise_product_status['Business Loan'] = { opted: false, count: 0 }
        @non_drwise_product_status['Business Loan'] = { opted: business_loans.exists?, count: business_loans.count }
      else
        @drwise_product_status['Personal Loan'] = { opted: false, count: 0 }
        @non_drwise_product_status['Personal Loan'] = { opted: false, count: 0 }
        @drwise_product_status['Home Loan'] = { opted: false, count: 0 }
        @non_drwise_product_status['Home Loan'] = { opted: false, count: 0 }
        @drwise_product_status['Business Loan'] = { opted: false, count: 0 }
        @non_drwise_product_status['Business Loan'] = { opted: false, count: 0 }
      end
    rescue
      @drwise_product_status['Personal Loan'] = { opted: false, count: 0 }
      @non_drwise_product_status['Personal Loan'] = { opted: false, count: 0 }
      @drwise_product_status['Home Loan'] = { opted: false, count: 0 }
      @non_drwise_product_status['Home Loan'] = { opted: false, count: 0 }
      @drwise_product_status['Business Loan'] = { opted: false, count: 0 }
      @non_drwise_product_status['Business Loan'] = { opted: false, count: 0 }
    end

    # Tax Services - DrWise vs Non-DrWise
    begin
      if @customer.respond_to?(:tax_services)
        itr_services = @customer.tax_services.where(service_type: 'ITR Filing')
        @drwise_product_status['ITR'] = { opted: false, count: 0 }
        @non_drwise_product_status['ITR'] = { opted: itr_services.exists?, count: itr_services.count }
      else
        @drwise_product_status['ITR'] = { opted: false, count: 0 }
        @non_drwise_product_status['ITR'] = { opted: false, count: 0 }
      end
    rescue
      @drwise_product_status['ITR'] = { opted: false, count: 0 }
      @non_drwise_product_status['ITR'] = { opted: false, count: 0 }
    end

    # Travel Services - DrWise vs Non-DrWise
    begin
      if @customer.respond_to?(:travel_packages)
        domestic = @customer.travel_packages.where(travel_type: 'Domestic')
        international = @customer.travel_packages.where(travel_type: 'International')

        @drwise_product_status['Domestic Travel'] = { opted: false, count: 0 }
        @non_drwise_product_status['Domestic Travel'] = { opted: domestic.exists?, count: domestic.count }

        @drwise_product_status['International Travel'] = { opted: false, count: 0 }
        @non_drwise_product_status['International Travel'] = { opted: international.exists?, count: international.count }
      else
        @drwise_product_status['Domestic Travel'] = { opted: false, count: 0 }
        @non_drwise_product_status['Domestic Travel'] = { opted: false, count: 0 }
        @drwise_product_status['International Travel'] = { opted: false, count: 0 }
        @non_drwise_product_status['International Travel'] = { opted: false, count: 0 }
      end
    rescue
      @drwise_product_status['Domestic Travel'] = { opted: false, count: 0 }
      @non_drwise_product_status['Domestic Travel'] = { opted: false, count: 0 }
      @drwise_product_status['International Travel'] = { opted: false, count: 0 }
      @non_drwise_product_status['International Travel'] = { opted: false, count: 0 }
    end

    # Keep backward compatibility
    @product_status['Mutual Fund'] = @non_drwise_product_status['Mutual Fund'][:opted]
    @product_status['Gold'] = @non_drwise_product_status['Gold'][:opted]
    @product_status['NPS'] = @non_drwise_product_status['NPS'][:opted]
    @product_status['Bonds'] = @non_drwise_product_status['Bonds'][:opted]
    @product_status['Personal'] = @non_drwise_product_status['Personal Loan'][:opted]
    @product_status['Home'] = @non_drwise_product_status['Home Loan'][:opted]
    @product_status['Business'] = @non_drwise_product_status['Business Loan'][:opted]
    @product_status['ITR'] = @non_drwise_product_status['ITR'][:opted]
    @product_status['Domestic'] = @non_drwise_product_status['Domestic Travel'][:opted]
    @product_status['International'] = @non_drwise_product_status['International Travel'][:opted]

    # Additional placeholder products for future expansion
    @product_status['Additional 1'] = false
    @product_status['Additional 2'] = false

    # Calculate DrWise vs Non-DrWise statistics
    @drwise_summary = {
      total_policies: @drwise_policy_status.values.sum { |policy| policy[:count] } +
                      @drwise_product_status.values.sum { |product| product[:count] },
      total_premium: @drwise_policy_status.values.sum { |policy| policy[:total_premium] || 0 },
      opted_count: @drwise_policy_status.values.count { |policy| policy[:opted] } +
                   @drwise_product_status.values.count { |product| product[:opted] }
    }

    @non_drwise_summary = {
      total_policies: @non_drwise_policy_status.values.sum { |policy| policy[:count] } +
                      @non_drwise_product_status.values.sum { |product| product[:count] },
      total_premium: @non_drwise_policy_status.values.sum { |policy| policy[:total_premium] || 0 },
      opted_count: @non_drwise_policy_status.values.count { |policy| policy[:opted] } +
                   @non_drwise_product_status.values.count { |product| product[:opted] }
    }

    # Calculate comprehensive commission data based on all 17 products
    total_policies = 0
    total_premium = 0
    opted_count = @product_status.values.count(true)

    # Count actual policies and premiums from existing insurance types
    total_policies += @policy_status.values.sum { |policy| policy[:count] }
    total_premium += @policy_status.values.sum { |policy| policy[:total_premium] }

    # Add counts from other product types (when they have data)
    begin
      if @customer.respond_to?(:investments)
        total_policies += @customer.investments.count
        total_premium += @customer.investments.sum(:investment_amount) || 0
      end

      if @customer.respond_to?(:loans)
        total_policies += @customer.loans.count
        total_premium += @customer.loans.sum(:loan_amount) || 0
      end

      if @customer.respond_to?(:tax_services)
        total_policies += @customer.tax_services.count
        total_premium += @customer.tax_services.sum(:amount) || 0
      end

      if @customer.respond_to?(:travel_packages)
        total_policies += @customer.travel_packages.count
        total_premium += @customer.travel_packages.sum(:package_amount) || 0
      end
    rescue
      # Handle cases where tables don't exist yet
    end

    @commission_summary = {
      total_premium: total_premium,
      total_policies: total_policies,
      opted_count: opted_count,
      total_products: 17, # Total number of product types available
      coverage_percentage: (opted_count.to_f / 17 * 100).round(1)
    }

    # Get commission payouts for this customer's policies
    @commission_payouts = CommissionPayout.joins(
      "LEFT JOIN health_insurances ON commission_payouts.policy_type = 'health' AND commission_payouts.policy_id = health_insurances.id
       LEFT JOIN life_insurances ON commission_payouts.policy_type = 'life' AND commission_payouts.policy_id = life_insurances.id
       LEFT JOIN motor_insurances ON commission_payouts.policy_type = 'motor' AND commission_payouts.policy_id = motor_insurances.id"
    ).where(
      "(commission_payouts.policy_type = 'health' AND health_insurances.customer_id = ?) OR
       (commission_payouts.policy_type = 'life' AND life_insurances.customer_id = ?) OR
       (commission_payouts.policy_type = 'motor' AND motor_insurances.customer_id = ?)",
      @customer.id, @customer.id, @customer.id
    ).includes(:payout_audit_logs)
  end

  # GET /admin/customers/new
  def new
    @customer = Customer.new
    @customer.status = true
    @sub_agents = SubAgent.active.order(:first_name, :last_name)

    # If lead_id is provided, populate customer with lead data
    if params[:lead_id].present?
      @lead = Lead.find(params[:lead_id])

      # Check if this lead is already converted to a customer
      if @lead.converted_customer_id.present?
        existing_customer = Customer.find_by(id: @lead.converted_customer_id)
        if existing_customer
          # Lead is already converted, redirect to the customer's edit page
          redirect_to edit_admin_customer_path(existing_customer),
                      notice: "This lead has already been converted to a customer. Redirected to the customer's edit page."
          return
        end
      end

      # For branch-out leads, check if there's already a customer from the parent or other branch leads
      if @lead.is_branch_out? && @lead.parent_lead_id.present?
        parent_lead = Lead.find_by(id: @lead.parent_lead_id)

        # Check if parent lead has a customer
        if parent_lead && parent_lead.converted_customer_id.present?
          existing_customer = Customer.find_by(id: parent_lead.converted_customer_id)
          if existing_customer
            # Update the branch-out lead to mark as converted with the same customer
            @lead.update!(
              current_stage: 'converted',
              converted_customer_id: existing_customer.id
            )
            redirect_to edit_admin_customer_path(existing_customer),
                        notice: "Branch-out lead linked to existing customer from parent lead. Redirected to customer's edit page."
            return
          end
        end

        # Check if any other branch-out leads from same parent are already converted
        if parent_lead
          other_branch_leads = Lead.where(parent_lead_id: parent_lead.id)
                                   .where.not(id: @lead.id)
                                   .where.not(converted_customer_id: nil)

          if other_branch_leads.any?
            converted_branch = other_branch_leads.first
            existing_customer = Customer.find_by(id: converted_branch.converted_customer_id)
            if existing_customer
              # Update this branch-out lead to use the same customer
              @lead.update!(
                current_stage: 'converted',
                converted_customer_id: existing_customer.id
              )
              redirect_to edit_admin_customer_path(existing_customer),
                          notice: "Branch-out lead linked to existing customer from sibling branch lead. Redirected to customer's edit page."
              return
            end
          end
        end
      end

      # Basic information mapping
      @customer.customer_type = @lead.customer_type
      @customer.email = @lead.email
      @customer.mobile = @lead.contact_number
      @customer.address = @lead.address
      @customer.city = @lead.city
      @customer.state = @lead.state

      # Individual customer mapping
      if @lead.individual?
        @customer.first_name = @lead.first_name
        @customer.middle_name = @lead.middle_name
        @customer.last_name = @lead.last_name
        @customer.birth_date = @lead.birth_date
        @customer.birth_place = @lead.birth_place
        @customer.gender = @lead.gender

        # Map height and weight with correct field names
        # Lead only has 'height' and 'weight' fields, map them to Customer's specific fields
        # Convert BigDecimal → Float → String so the value matches the dropdown option format ("5.08", not "0.508e1")
        @customer.height_feet = @lead.height.present? ? @lead.height.to_f.to_s : nil
        @customer.weight_kg = @lead.weight

        @customer.education = @lead.education
        @customer.marital_status = @lead.marital_status
        @customer.business_job = @lead.business_job

        # Map business/job name with fallbacks
        @customer.business_name = @lead.business_name
        @customer.job_name = @lead.job_name
        @customer.occupation = @lead.occupation

        @customer.type_of_duty = @lead.type_of_duty
        @customer.annual_income = @lead.annual_income

        # Map PAN to both fields for compatibility
        @customer.pan_no = @lead.pan_no
        @customer.pan_number = @lead.pan_no

        @customer.additional_information = @lead.additional_information
      # Corporate customer mapping
      elsif @lead.corporate?
        @customer.company_name = @lead.company_name

        # Map PAN to both fields for compatibility
        @customer.pan_no = @lead.pan_no
        @customer.pan_number = @lead.pan_no

        # Map GST to both fields for compatibility
        @customer.gst_no = @lead.gst_no
        @customer.gst_number = @lead.gst_no

        @customer.annual_income = @lead.annual_income
        @customer.additional_information = @lead.additional_information
      else
        # Fallback for legacy data
        @customer.first_name = extract_first_name(@lead.name)
        @customer.last_name = extract_last_name(@lead.name)
      end

      # Auto-populate affiliate from lead
      if @lead.affiliate_id.present?
        @customer.sub_agent_id = @lead.affiliate_id
      end

      # Calculate age if birth_date is present
      if @customer.birth_date.present?
        @customer.age = calculate_age(@customer.birth_date)
      end

      # Store lead reference for future conversion
      @customer.lead_id = @lead.lead_id

      # Set default required information if not provided by lead
      # These are mandatory fields for customer creation

      # Birth date is required - set a default if missing
      if @customer.birth_date.blank?
        # Set a default age of 30 years old
        @customer.birth_date = 30.years.ago.to_date
      end

      # Nominee information is required
      if @customer.nominee_name.blank?
        @customer.nominee_name = "To be updated"
      end

      if @customer.nominee_relation.blank?
        @customer.nominee_relation = "other"
      end

      if @customer.nominee_date_of_birth.blank?
        # Set a default date - 25 years ago from today
        @customer.nominee_date_of_birth = 25.years.ago.to_date
      end
    end
  end

  # GET /admin/customers/1/edit
  def edit
    @sub_agents = SubAgent.active.order(:first_name, :last_name)
  end

  # POST /admin/customers
  def create
    # Extract password params separately before creating customer
    password = params[:customer][:password]
    password_confirmation = params[:customer][:password_confirmation]
    user_enter_password = params[:customer][:user_enter_password]

    @customer = Customer.new(customer_params)

    # Handle lead_id parameter - set lead_id from URL parameter if present and not already set
    if params[:lead_id].present? && @customer.lead_id.blank?
      @lead = Lead.find(params[:lead_id])
      @customer.lead_id = @lead.lead_id
    end

    success = false
    error_message = nil
    generated_password = nil
    user_created = false

    begin
      ActiveRecord::Base.transaction do
        if @customer.save
          # Handle profile image upload to R2
          begin
            handle_profile_image_upload if params[:customer]&.[](:profile_image).present?
          rescue => upload_error
            Rails.logger.error "Profile image upload failed: #{upload_error.message}"
            # Continue with customer creation even if profile image upload fails
          end

          # Handle document file uploads after customer creation (with error handling)
          begin
            handle_customer_document_uploads if params[:customer]&.[](:documents_attributes).present?
          rescue => upload_error
            Rails.logger.error "Document upload failed: #{upload_error.message}"
            # Continue with customer creation even if document upload fails
          end

          # Update lead if customer was created from a lead
          if @customer.lead_id.present?
            lead = Lead.find_by(lead_id: @customer.lead_id)
            if lead
              lead.update!(
                current_stage: 'converted',
                converted_customer_id: @customer.id,
                stage_updated_at: Time.current
              )
            end
          end

          # Create User account - auto-generate password if not provided
          should_create_user = user_enter_password == '1' ||
                             (@customer.email.present? && password.blank?)

          if should_create_user
            # Skip user creation if a user with this email/mobile already exists (e.g. existing affiliate)
            existing_user = User.find_by(email: @customer.email) ||
                            (@customer.mobile.present? && User.find_by(mobile: @customer.mobile))

            if existing_user
              success = true
            else
              user_first_name = @customer.individual? ? @customer.first_name : @customer.company_name
              user_last_name = @customer.individual? ? (@customer.last_name || @customer.company_name) : @customer.company_name

              if password.present? && password_confirmation.present?
                # Use provided password
                if password == password_confirmation
                  generated_password = password
                  User.create!(
                    first_name: user_first_name,
                    last_name: user_last_name,
                    email: @customer.email,
                    mobile: @customer.mobile,
                    password: generated_password,
                    password_confirmation: generated_password,
                    original_password: generated_password,
                    user_type: 'customer',
                    status: true
                  )
                  user_created = true
                  success = true
                else
                  @customer.destroy
                  @customer.errors.add(:password_confirmation, "doesn't match Password")
                  success = false
                end
              else
                # Auto-generate password if no password provided but user account creation requested
                generated_password = generate_secure_password
                User.create!(
                  first_name: user_first_name,
                  last_name: user_last_name,
                  email: @customer.email,
                  mobile: @customer.mobile,
                  password: generated_password,
                  password_confirmation: generated_password,
                  original_password: generated_password,
                  user_type: 'customer',
                  status: true
                )
                user_created = true
                success = true
              end
            end
          else
            success = true
          end
        else
          success = false
        end
      end
    rescue => e
      Rails.logger.error "Customer creation error: #{e.message}"
      error_message = "Failed to create customer: #{e.message}"
      success = false
    end

    # Handle response based on success/failure - single render/redirect point
    if success
      base_notice = if user_created && generated_password.present?
        flash[:generated_password] = generated_password
        "Customer created successfully. Auto-generated password: #{generated_password}"
      elsif user_created
        'Customer and login account created successfully.'
      else
        'Customer was successfully created.'
      end

      lead_for_redirect = @customer.lead_id.present? ? Lead.find_by(lead_id: @customer.lead_id) : nil
      redirect_path = lead_product_redirect_path(lead_for_redirect, @customer)
      redirect_path ||= product_selection_admin_customer_path(@customer)

      redirect_to redirect_path, notice: base_notice
    else
      if error_message
        @customer.errors.add(:base, error_message)
      end
      @sub_agents = SubAgent.active.order(:first_name, :last_name)
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /admin/customers/1
  def update
    begin
      # Handle uploaded_documents separately for R2 upload
      uploaded_documents_attrs = params[:customer]&.[](:uploaded_documents_attributes)

      if @customer.update(customer_params.except(:uploaded_documents_attributes))
        # Handle profile image upload to R2
        begin
          handle_profile_image_upload if params[:customer]&.[](:profile_image).present?
        rescue => upload_error
          Rails.logger.error "Profile image upload failed: #{upload_error.message}"
          # Continue with customer update even if profile image upload fails
        end

        # Handle R2 document uploads after customer is saved
        upload_success = handle_document_uploads(uploaded_documents_attrs) if uploaded_documents_attrs.present?

        success_message = 'Customer was successfully updated.'
        if uploaded_documents_attrs.present? && !upload_success
          success_message += ' Some documents failed to upload to cloud storage.'
        end

        redirect_to admin_customer_path(@customer), notice: success_message
      else
        @sub_agents = SubAgent.active.order(:first_name, :last_name)
        render :edit, status: :unprocessable_entity
      end
    rescue ActiveRecord::AssociationTypeMismatch => e
      Rails.logger.error "Customer update failed - Association error: #{e.message}"
      Rails.logger.error "Customer params: #{customer_params.inspect}"

      # Clear problematic association data and retry without it
      safe_params = customer_params.except(:documents, :uploaded_documents_attributes)
      if @customer.update(safe_params)
        redirect_to admin_customer_path(@customer), notice: 'Customer was successfully updated (documents skipped due to error).'
      else
        @sub_agents = SubAgent.active.order(:first_name, :last_name)
        flash.now[:alert] = "Update failed: #{e.message}"
        render :edit, status: :unprocessable_entity
      end
    end
  end

  # GET /admin/customers/1/associations_summary
  def associations_summary
    counts = {
      'Health Policies'    => @customer.health_insurances.count,
      'Life Policies'      => @customer.life_insurances.count,
      'Motor Policies'     => @customer.motor_insurances.count,
      'Other Policies'     => @customer.other_insurances.count,
      'Mutual Funds'       => @customer.mutual_funds.count,
      'Appointments'       => @customer.appointments.count,
      'Helpdesk Tickets'   => @customer.helpdesk_tickets.count,
      'Loans'              => @customer.loans.count,
      'Investments'        => @customer.investments.count,
      'Family Members'     => @customer.family_members.count,
      'Documents'          => @customer.documents.count,
    }.reject { |_, v| v == 0 }

    render json: { associations: counts, total: counts.values.sum }
  end

  # DELETE /admin/customers/1
  def destroy
    if params[:force] == 'true'
      @customer.destroy
      redirect_to admin_customers_path, notice: "Customer \"#{@customer.display_name}\" and all associated records were permanently deleted."
    else
      redirect_to admin_customer_path(@customer), alert: 'Use the delete confirmation to remove this customer.'
    end
  end

  # PATCH /admin/customers/1/toggle_status
  def toggle_status
    @customer.update(status: !@customer.status)
    status_text = @customer.status? ? 'activated' : 'deactivated'
    redirect_to admin_customers_path, notice: "Customer was successfully #{status_text}."
  end

  # PATCH /admin/customers/1/deactivate
  def deactivate
    if @customer.deactivate!
      redirect_to admin_customers_path, notice: 'Customer was successfully deactivated.'
    else
      redirect_to admin_customers_path, alert: 'Failed to deactivate customer.'
    end
  end

  # PATCH /admin/customers/1/activate
  def activate
    if @customer.activate!
      redirect_to admin_customers_path, notice: 'Customer was successfully activated.'
    else
      redirect_to admin_customers_path, alert: 'Failed to activate customer.'
    end
  end

  # GET /admin/customers/export
  def export
    @customers = Customer.includes(:policies)

    # Apply same filters as index
    if params[:search].present?
      @customers = @customers.search_customers(params[:search])
    end

    if params[:customer_type].present?
      @customers = @customers.where(customer_type: params[:customer_type])
    end

    case params[:status]
    when 'active'
      @customers = @customers.active
    when 'inactive'
      @customers = @customers.inactive
    end

    @customers = @customers.order(:created_at)

    respond_to do |format|
      format.csv do
        send_data generate_customers_csv(@customers), filename: "customers_#{Date.current}.csv"
      end
      # format.xlsx do
      #   send_data generate_customers_xlsx(@customers), filename: "customers_#{Date.current}.xlsx"
      # end
    end
  end

  # GET /admin/customers/download
  def download
    format_type = params[:format_type] # csv_individual, csv_corporate, excel_individual, excel_corporate

    scope = build_filtered_scope

    case format_type
    when 'csv_individual'
      customers = scope.where(customer_type: 'individual').order(:created_at)
      send_data generate_customers_csv_full(customers, 'individual'),
                filename: "individual_customers_#{Date.current}.csv",
                type: 'text/csv'
    when 'csv_corporate'
      customers = scope.where(customer_type: 'corporate').order(:created_at)
      send_data generate_customers_csv_full(customers, 'corporate'),
                filename: "corporate_customers_#{Date.current}.csv",
                type: 'text/csv'
    when 'excel_individual'
      customers = scope.where(customer_type: 'individual').order(:created_at)
      send_data generate_customers_excel(customers, 'individual'),
                filename: "individual_customers_#{Date.current}.xlsx",
                type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    when 'excel_corporate'
      customers = scope.where(customer_type: 'corporate').order(:created_at)
      send_data generate_customers_excel(customers, 'corporate'),
                filename: "corporate_customers_#{Date.current}.xlsx",
                type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    else
      redirect_to admin_customers_path, alert: 'Invalid download format.'
    end
  end

  # GET /admin/customers/:id/product_selection
  def product_selection
    # Available products for selection
    @products = [
      { name: 'Health Insurance', path: new_admin_health_insurance_path(customer_id: @customer.id), icon: 'heart-pulse', description: 'Medical coverage and health protection' },
      { name: 'Life Insurance', path: new_admin_life_insurance_path(customer_id: @customer.id), icon: 'shield-heart', description: 'Life coverage and financial security' },
      { name: 'Motor Insurance', path: new_admin_motor_insurance_path(customer_id: @customer.id), icon: 'car-front', description: 'Vehicle insurance coverage' },
      { name: 'Other Insurance', path: new_admin_other_insurance_path(customer_id: @customer.id), icon: 'shield-check', description: 'General insurance - Travel, Property, Cyber, etc.' },
      { name: 'Investment', path: '#', icon: 'graph-up', description: 'Investment opportunities and plans' },
      { name: 'Loans', path: '#', icon: 'cash-coin', description: 'Personal and business loan options' },
      { name: 'Tax Services', path: '#', icon: 'receipt', description: 'Tax planning and consultation' },
      { name: 'Travel Packages', path: '#', icon: 'airplane', description: 'Travel insurance and packages' }
    ]
  end

  # API endpoint for cities
  def cities
    state = params[:state]
    query = params[:query]

    # Return all cities for the selected state
    cities = LocationData.cities_for_state(state)

    render json: { cities: cities }
  end

  # API endpoint for searching sub agents (affiliates)
  def search_sub_agents
    query = params[:q] || params[:query]
    limit = params[:limit]&.to_i || 20
    affiliates = []

    if query.present? && query.strip.length >= 2
      # Search with query
      affiliates = SubAgent.active
                          .where("LOWER(first_name || ' ' || last_name) ILIKE ?", "%#{query.downcase}%")
                          .limit(limit)
                          .map { |agent| { id: agent.id, text: agent.display_name } }
    elsif query.blank? || query.strip.empty?
      # Return default affiliates when no search query (show recently active or all)
      affiliates = SubAgent.active
                          .order(:first_name, :last_name)
                          .limit([limit, 10].min) # Show max 10 when no search
                          .map { |agent| { id: agent.id, text: agent.display_name } }
    end

    render json: { results: affiliates }
  end

  # AJAX endpoint for fetching family members - reload trigger
  def family_members
    customer = Customer.find(params[:id])
    family_members = customer.family_members.map do |member|
      {
        id: member.id,
        name: member.name,
        relationship: member.relationship.humanize
      }
    end
    render json: { family_members: family_members }
  rescue ActiveRecord::RecordNotFound
    render json: { family_members: [] }, status: :not_found
  end

  # AJAX endpoint for fetching affiliate info
  def affiliate_info
    customer = Customer.find(params[:id])
    render json: { affiliate_id: customer.sub_agent_id }
  rescue ActiveRecord::RecordNotFound
    render json: { affiliate_id: nil }, status: :not_found
  end

  def nominee_details
    customer = Customer.find(params[:id])
    render json: {
      nominee_name: customer.nominee_name,
      nominee_relation: customer.nominee_relation,
      nominee_date_of_birth: customer.nominee_date_of_birth&.strftime("%Y-%m-%d")
    }
  rescue ActiveRecord::RecordNotFound
    render json: {
      nominee_name: nil,
      nominee_relation: nil,
      nominee_date_of_birth: nil
    }, status: :not_found
  end

  private

  # Determine redirect path after customer creation based on lead product category/subcategory
  def lead_product_redirect_path(lead, customer)
    return nil unless lead.present? && lead.product_category.present? && lead.product_subcategory.present?

    case lead.product_category
    when 'insurance'
      case lead.product_subcategory
      when 'health' then new_admin_health_insurance_path(customer_id: customer.id, lead_id: lead.id)
      when 'life'   then new_admin_life_insurance_path(customer_id: customer.id, lead_id: lead.id)
      when 'motor'  then new_admin_motor_insurance_path(customer_id: customer.id, lead_id: lead.id)
      when 'general', 'travel', 'other' then new_admin_other_insurance_path(customer_id: customer.id, lead_id: lead.id)
      end
    else
      service_type = {
        'taxation'    => { 'itr' => 'taxation_itr', 'tax_planning' => 'taxation_tax_planning' },
        'loans'       => { 'personal' => 'loans_personal', 'home' => 'loans_home', 'mortgage' => 'loans_mortgage', 'business' => 'loans_business' },
        'travel'      => { 'domestic' => 'travel_domestic', 'international' => 'travel_international' },
        'credit_card' => { 'rewards' => 'credit_card_rewards', 'business' => 'credit_card_business', 'travel' => 'credit_card_travel' },
        'investments' => { 'mutual_fund' => 'investments_mutual_fund', 'fd' => 'investments_fd', 'other' => 'investments_other' }
      }.dig(lead.product_category, lead.product_subcategory)

      service_type.present? ? new_admin_client_service_path(service_type: service_type, customer_id: customer.id, lead_id: lead.id) : nil
    end
  end

  # Generate a secure password for auto-creation
  def generate_secure_password
    # Generate password in format: first 4 letters of name + @ + 4-digit year from DOB
    # Example: PRAMOD with DOB 26/02/1996 becomes PRAM@1996

    # Use first_name for individual, company_name for corporate
    name_source = @customer.individual? ? @customer.first_name : @customer.company_name
    first_name = name_source.to_s.strip.upcase

    # Get first 4 characters of name, pad with 'X' if less than 4 characters
    name_part = first_name[0..3].ljust(4, 'X')

    # Get birth year from birth_date
    if @customer.birth_date.present?
      year_part = @customer.birth_date.year.to_s
    else
      # Default to current year if no birth date
      year_part = Date.current.year.to_s
    end

    "#{name_part}@#{year_part}"
  end

  def set_customer
    @customer = Customer.find(params[:id])
  end

  def handle_document_uploads(uploaded_documents_attrs)
    return true unless uploaded_documents_attrs.present?

    all_success = true

    uploaded_documents_attrs.each do |index, doc_attrs|
      next if doc_attrs[:_destroy] == '1' || doc_attrs[:file].blank?

      # Skip if no file provided
      file_param = doc_attrs[:file]
      next unless file_param.present?

      begin
        # Create document record first
        document = @customer.uploaded_documents.build(
          title: doc_attrs[:title],
          description: doc_attrs[:description],
          document_type: doc_attrs[:document_type],
          uploaded_by: doc_attrs[:uploaded_by] || current_user&.email || 'Admin User'
        )

        if document.save
          # Upload file to R2
          upload_result = document.upload_to_r2(file_param)

          if upload_result[:success]
            Rails.logger.info "Successfully uploaded document: #{document.title}"
          else
            Rails.logger.error "Failed to upload document: #{upload_result[:error]}"
            document.destroy # Clean up failed document record
            all_success = false
          end
        else
          Rails.logger.error "Failed to create document: #{document.errors.full_messages}"
          all_success = false
        end
      rescue => e
        Rails.logger.error "Document upload error: #{e.message}"
        all_success = false
      end
    end

    all_success
  end

  def customer_params
    permitted_params = params.require(:customer).permit(
      :customer_type, :first_name, :middle_name, :last_name, :company_name, :email, :mobile,
      :address, :state, :city, :pincode, :pan_no, :pan_number, :gst_no, :gst_number, :birth_date,
      :gender, :occupation, :job_name, :annual_income, :nominee_name, :nominee_relation,
      :nominee_date_of_birth, :status, :birth_place, :height_feet, :weight_kg, :education,
      :marital_status, :business_job, :business_name, :type_of_duty, :additional_information, :additional_info,
      :bank_name, :account_no, :ifsc_code, :anniversary_date,
      :added_by, :sub_agent_id, :age, :lead_id,
      profile_images: [],
      documents: [],
      documents_attributes: [:id, :document_type, :document_file, :_destroy],
      uploaded_documents_attributes: [:id, :title, :description, :document_type, :file, :uploaded_by, :_destroy],
      family_members_attributes: [
        :id, :first_name, :middle_name, :last_name, :birth_date, :age, :height_feet, :weight_kg,
        :gender, :relationship, :pan_no, :mobile, :additional_information, :_destroy,
        documents_attributes: [:id, :document_type, :file, :_destroy]
      ],
      corporate_members_attributes: [
        :id, :company_name, :mobile, :email, :state, :city, :address, :annual_income,
        :pan_no, :gst_no, :additional_information, :_destroy,
        documents_attributes: [:id, :document_type, :file, :_destroy]
      ]
    )

    # Filter out blank string values from documents array to prevent association errors
    if permitted_params[:documents].present?
      permitted_params[:documents] = permitted_params[:documents].reject(&:blank?)
    end

    permitted_params
  end

  def handle_customer_document_uploads
    return unless @customer&.documents&.any?

    @customer.documents.each do |document|
      # Check if document has a file uploaded via the virtual attribute
      if document.document_file.present?
        # Upload file to R2
        upload_result = document.upload_to_r2(document.document_file)

        if upload_result[:success]
          Rails.logger.info "Successfully uploaded customer document to R2: #{upload_result[:key]}"
        else
          Rails.logger.error "Failed to upload customer document to R2: #{upload_result[:error]}"
          # Don't fail the whole transaction, just log the error
        end
      end
    end
  end

  def handle_profile_image_upload
    profile_image_file = params[:customer][:profile_image]
    return unless profile_image_file.present?

    # Create or find existing profile image document
    profile_document = @customer.documents.find_or_initialize_by(document_type: 'Profile Image')

    # Upload file to R2
    upload_result = profile_document.upload_to_r2(profile_image_file)

    if upload_result[:success]
      # Save the document record if it's new
      profile_document.save! if profile_document.new_record?
      Rails.logger.info "Successfully uploaded profile image to R2: #{upload_result[:key]}"
    else
      Rails.logger.error "Failed to upload profile image to R2: #{upload_result[:error]}"
      raise "Profile image upload failed: #{upload_result[:error]}"
    end
  end

  def build_filtered_scope
    scope = Customer.all

    if params[:search].present? && params[:search].strip.length >= 4
      scope = scope.search_customers(params[:search].strip)
    end

    if params[:lead_id_search].present? && params[:lead_id_search].strip.length >= 4
      term = params[:lead_id_search].strip
      scope = scope.where("lead_id ILIKE ? OR lead_id ILIKE ?", term, "%#{term}%")
    end

    if params[:customer_type].present?
      scope = scope.where(customer_type: params[:customer_type])
    end

    case params[:status]
    when 'active'  then scope = scope.where(status: true)
    when 'inactive' then scope = scope.where(status: false)
    end

    scope
  end

  def generate_customers_csv_full(customers, _type)
    require 'csv'
    CSV.generate(headers: true) do |csv|
      csv << %w[
        ID LeadID CustomerType FirstName MiddleName LastName CompanyName
        Email Mobile Address State City Pincode BirthDate Age Gender
        HeightFeet WeightKg Education MaritalStatus Occupation JobName
        BusinessName BusinessJob TypeOfDuty AnnualIncome PANNumber GSTNumber
        BirthPlace NomineeName NomineeRelation NomineeDOB SubAgent Status
        AddedBy CreatedAt
      ]
      customers.find_each do |c|
        csv << [
          c.id, c.lead_id, c.customer_type&.humanize,
          c.first_name, c.middle_name, c.last_name, c.company_name,
          c.email, c.mobile, c.address, c.state, c.city, c.pincode,
          c.birth_date, c.age, c.gender&.humanize,
          c.height_feet, c.weight_kg, c.education,
          c.marital_status&.humanize, c.occupation, c.job_name,
          c.business_name, c.business_job, c.type_of_duty, c.annual_income,
          c.pan_number, c.gst_number, c.birth_place,
          c.nominee_name, c.nominee_relation, c.nominee_date_of_birth,
          c.sub_agent, c.status? ? 'Active' : 'Inactive',
          c.added_by&.humanize, c.created_at.strftime('%Y-%m-%d %H:%M:%S')
        ]
      end
    end
  end

  def generate_customers_excel(customers, type)
    require 'caxlsx'
    package = Axlsx::Package.new
    wb = package.workbook

    header_style = wb.styles.add_style(
      bg_color: '2E7D32', fg_color: 'FFFFFF',
      b: true, alignment: { horizontal: :center }
    )
    row_style = wb.styles.add_style(alignment: { horizontal: :left })

    sheet_name = type == 'individual' ? 'Individual Customers' : 'Corporate Customers'
    wb.add_worksheet(name: sheet_name) do |sheet|
      headers = %w[
        ID LeadID CustomerType FirstName MiddleName LastName CompanyName
        Email Mobile Address State City Pincode BirthDate Age Gender
        HeightFeet WeightKg Education MaritalStatus Occupation JobName
        BusinessName BusinessJob TypeOfDuty AnnualIncome PANNumber GSTNumber
        BirthPlace NomineeName NomineeRelation NomineeDOB SubAgent Status
        AddedBy CreatedAt
      ]
      sheet.add_row headers, style: header_style

      customers.find_each do |c|
        sheet.add_row([
          c.id, c.lead_id, c.customer_type&.humanize,
          c.first_name, c.middle_name, c.last_name, c.company_name,
          c.email, c.mobile, c.address, c.state, c.city, c.pincode,
          c.birth_date&.to_s, c.age, c.gender&.humanize,
          c.height_feet, c.weight_kg&.to_f, c.education,
          c.marital_status&.humanize, c.occupation, c.job_name,
          c.business_name, c.business_job, c.type_of_duty,
          c.annual_income&.to_f, c.pan_number, c.gst_number, c.birth_place,
          c.nominee_name, c.nominee_relation, c.nominee_date_of_birth&.to_s,
          c.sub_agent, c.status? ? 'Active' : 'Inactive',
          c.added_by&.humanize, c.created_at.strftime('%Y-%m-%d %H:%M:%S')
        ], style: row_style)
      end
    end

    package.to_stream.read
  end

  def generate_customers_csv(customers)
    require 'csv'

    CSV.generate(headers: true) do |csv|
      csv << %w[
        ID CustomerType FirstName LastName CompanyName Email Mobile
        Address State City Pincode BirthDate Gender Height Weight
        Education MaritalStatus Occupation JobName TypeOfDuty AnnualIncome
        PANNumber GSTNumber BirthPlace NomineeName NomineeRelation
        NomineeDOB Status AddedBy CreatedAt
      ]

      customers.find_each do |customer|
        csv << [
          customer.id,
          customer.customer_type&.humanize,
          customer.first_name,
          customer.last_name,
          customer.company_name,
          customer.email,
          customer.mobile,
          customer.address,
          customer.state,
          customer.city,
          customer.pincode,
          customer.birth_date,
          customer.gender&.humanize,
          customer.height,
          customer.weight,
          customer.education,
          customer.marital_status&.humanize,
          customer.occupation,
          customer.job_name,
          customer.type_of_duty,
          customer.annual_income,
          customer.pan_number,
          customer.gst_number,
          customer.birth_place,
          customer.nominee_name,
          customer.nominee_relation,
          customer.nominee_date_of_birth,
          customer.status? ? 'Active' : 'Inactive',
          customer.added_by&.humanize,
          customer.created_at.strftime('%Y-%m-%d %H:%M:%S')
        ]
      end
    end
  end

  def generate_customers_xlsx(customers)
    require 'rubyXL'

    workbook = RubyXL::Workbook.new
    worksheet = workbook[0]
    worksheet.sheet_name = 'Customers'

    # Headers
    headers = %w[
      ID CustomerType FirstName LastName CompanyName Email Mobile
      Address State City Pincode BirthDate Gender Height Weight
      Education MaritalStatus Occupation JobName TypeOfDuty AnnualIncome
      PANNumber GSTNumber BirthPlace NomineeName NomineeRelation
      NomineeDOB Status AddedBy CreatedAt
    ]

    headers.each_with_index do |header, index|
      worksheet.add_cell(0, index, header)
      worksheet.sheet_data[0][index].change_font_bold(true)
    end

    # Data rows
    customers.each_with_index do |customer, row_index|
      row = row_index + 1
      data = [
        customer.id,
        customer.customer_type&.humanize,
        customer.first_name,
        customer.last_name,
        customer.company_name,
        customer.email,
        customer.mobile,
        customer.address,
        customer.state,
        customer.city,
        customer.pincode,
        customer.birth_date,
        customer.gender&.humanize,
        customer.height,
        customer.weight,
        customer.education,
        customer.marital_status&.humanize,
        customer.occupation,
        customer.job_name,
        customer.type_of_duty,
        customer.annual_income,
        customer.pan_number,
        customer.gst_number,
        customer.birth_place,
        customer.nominee_name,
        customer.nominee_relation,
        customer.nominee_date_of_birth,
        customer.status? ? 'Active' : 'Inactive',
        customer.added_by&.humanize,
        customer.created_at.strftime('%Y-%m-%d %H:%M:%S')
      ]

      data.each_with_index do |value, col_index|
        worksheet.add_cell(row, col_index, value)
      end
    end

    workbook.stream.string
  end

  def extract_first_name(full_name)
    full_name.to_s.split(' ').first || 'Unknown'
  end

  def extract_last_name(full_name)
    names = full_name.to_s.split(' ')
    names.length > 1 ? names[1..-1].join(' ') : 'Unknown'
  end

  # Calculate age from birth date with detailed format (years and days)
  def calculate_age(birth_date)
    return '' unless birth_date

    today = Date.current

    # Calculate years
    years = today.year - birth_date.year

    # Calculate if birthday hasn't occurred this year yet
    if today.month < birth_date.month || (today.month == birth_date.month && today.day < birth_date.day)
      years -= 1
    end

    if years == 0
      # If less than a year old, calculate days from birth
      days = (today - birth_date).to_i
      "#{days} days"
    else
      # Calculate days since last birthday
      last_birthday = Date.new(today.year, birth_date.month, birth_date.day)
      if last_birthday > today
        last_birthday = Date.new(today.year - 1, birth_date.month, birth_date.day)
      end

      days = (today - last_birthday).to_i

      if days == 0
        "#{years} years"
      else
        "#{years} years, #{days} days"
      end
    end
  end

  # GET /admin/customers/:id/get_policies
  def get_policies
    type = params[:type] # 'drwise' or 'non-drwise'
    insurance_type = params[:insurance_type] # 'motor', 'life', 'health'

    begin
      case insurance_type
      when 'motor', 'motorinsurance'
        policies = fetch_motor_policies(@customer, type)
      when 'life', 'lifeinsurance'
        policies = fetch_life_policies(@customer, type)
      when 'health', 'healthinsurance'
        policies = fetch_health_policies(@customer, type)
      else
        return render json: { success: false, error: 'Invalid insurance type' }, status: 400
      end

      render json: {
        success: true,
        policies: policies,
        count: policies.count,
        insurance_type: insurance_type,
        customer_name: @customer.display_name
      }
    rescue => e
      Rails.logger.error "Error fetching #{insurance_type} insurance policies: #{e.message}"
      render json: {
        success: false,
        error: "Failed to load #{insurance_type} insurance policies",
        message: e.message
      }, status: 500
    end
  end

  private

  def fetch_motor_policies(customer, type)
    return [] unless defined?(MotorInsurance) && customer.respond_to?(:motor_insurances)

    policies = if type == 'drwise'
      # DrWise: Admin or Agent added policies
      customer.motor_insurances.where(
        '(is_admin_added = ? AND is_customer_added = ? AND is_agent_added = ?) OR (is_agent_added = ? AND is_customer_added = ? AND is_admin_added = ?)',
        true, false, false, true, false, false
      )
    else
      # Non-DrWise: Customer added policies
      customer.motor_insurances.where(is_customer_added: true, is_admin_added: false, is_agent_added: false)
    end

    policies.map do |policy|
      {
        id: policy.id,
        policy_number: policy.policy_number || "POL-#{policy.id}",
        insurance_company: policy.insurance_company_name || policy.try(:insurance_company) || 'N/A',
        policy_type: policy.policy_type || 'Motor Insurance',
        vehicle_details: "#{policy.make} #{policy.model} - #{policy.registration_number}",
        premium_amount: policy.total_premium || policy.try(:premium_amount) || 0,
        policy_start_date: policy.policy_start_date,
        policy_end_date: policy.policy_end_date,
        additional_info: {
          vehicle_type: policy.vehicle_type,
          manufacturing_year: policy.mfy,
          idv_value: policy.total_idv,
          make: policy.make,
          model: policy.model
        },
        status: determine_policy_status(policy),
        created_at: policy.created_at
      }
    end
  end

  def fetch_life_policies(customer, type)
    return [] unless defined?(LifeInsurance) && customer.respond_to?(:life_insurances)

    policies = if type == 'drwise'
      # DrWise: Admin or Agent added policies
      customer.life_insurances.where(
        '(is_admin_added = ? AND is_customer_added = ? AND is_agent_added = ?) OR (is_agent_added = ? AND is_customer_added = ? AND is_admin_added = ?)',
        true, false, false, true, false, false
      )
    else
      # Non-DrWise: Customer added policies
      customer.life_insurances.where(is_customer_added: true, is_admin_added: false, is_agent_added: false)
    end

    policies.map do |policy|
      {
        id: policy.id,
        policy_number: policy.policy_number || "LIFE-#{policy.id}",
        insurance_company: policy.insurance_company_name || 'N/A',
        policy_type: policy.policy_type || 'Life Insurance',
        policy_details: "#{policy.plan_name || 'N/A'} - Sum Assured: Rs. #{format_currency(policy.sum_insured || 0)}",
        premium_amount: policy.total_premium || policy.net_premium || 0,
        policy_start_date: policy.policy_start_date,
        policy_end_date: policy.policy_end_date,
        additional_info: {
          plan_name: policy.plan_name,
          sum_insured: policy.sum_insured || 0,
          policy_holder: policy.policy_holder,
          payment_mode: policy.payment_mode,
          policy_term: policy.try(:policy_term),
          premium_payment_term: policy.try(:premium_payment_term)
        },
        status: determine_policy_status(policy),
        created_at: policy.created_at
      }
    end
  end

  def fetch_health_policies(customer, type)
    return [] unless defined?(HealthInsurance) && customer.respond_to?(:health_insurances)

    policies = if type == 'drwise'
      # DrWise: Admin or Agent added policies
      customer.health_insurances.where(
        '(is_admin_added = ? AND is_customer_added = ? AND is_agent_added = ?) OR (is_agent_added = ? AND is_customer_added = ? AND is_admin_added = ?)',
        true, false, false, true, false, false
      )
    else
      # Non-DrWise: Customer added policies
      customer.health_insurances.where(is_customer_added: true, is_admin_added: false, is_agent_added: false)
    end

    policies.map do |policy|
      {
        id: policy.id,
        policy_number: policy.policy_number || "HEALTH-#{policy.id}",
        insurance_company: policy.insurance_company_name || 'N/A',
        policy_type: policy.policy_type || 'Health Insurance',
        policy_details: "#{policy.plan_name} - Sum Insured: Rs. #{policy.sum_insured || 0}",
        premium_amount: policy.total_premium || policy.net_premium || 0,
        policy_start_date: policy.policy_start_date,
        policy_end_date: policy.policy_end_date,
        additional_info: {
          plan_name: policy.plan_name,
          sum_insured: policy.sum_insured,
          policy_holder: policy.policy_holder,
          payment_mode: policy.payment_mode,
          insurance_type: policy.try(:insurance_type)
        },
        status: determine_policy_status(policy),
        created_at: policy.created_at
      }
    end
  end

  private

  def api_request?
    params[:type].present? && params[:insurance_type].present?
  end

  def determine_policy_status(policy)
    return 'Active' unless policy.policy_end_date

    today = Date.current
    end_date = policy.policy_end_date

    if end_date < today
      'Expired'
    elsif end_date <= today + 30.days
      'Expiring Soon'
    else
      'Active'
    end
  end

  def format_currency(amount)
    return "Rs. 0.00" if amount.nil? || amount.zero?
    amount = amount.to_f
    integer_part = amount.to_i.to_s
    decimal_part = sprintf("%.2f", amount).split('.').last
    reversed = integer_part.reverse
    result = []
    reversed.chars.each_with_index do |char, index|
      result << char
      if index == 2 && reversed.length > 3
        result << ','
      elsif index > 2 && (index - 2) % 2 == 0 && index < reversed.length - 1
        result << ','
      end
    end
    "Rs. #{result.reverse.join}.#{decimal_part}"
  end

  # Helper method to check if a policy can be renewed
  def policy_can_be_renewed?(policy)
    return false unless policy
    return false unless policy.respond_to?(:policy_end_date) && policy.policy_end_date

    # Check if policy expires within next 60 days and is not already a renewal
    policy.policy_end_date <= 60.days.from_now &&
    (!policy.respond_to?(:policy_type) || policy.policy_type != 'Renewal') &&
    (!policy.respond_to?(:is_renewal?) || !policy.is_renewal?)
  end
end