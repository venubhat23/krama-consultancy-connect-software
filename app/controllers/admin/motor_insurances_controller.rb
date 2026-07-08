class Admin::MotorInsurancesController < Admin::ApplicationController
  include ConfigurablePagination

  # Ensure CSRF protection
  protect_from_forgery with: :exception, except: [:create_renewal]

  # Custom CSRF handling for renewal action
  before_action :verify_renewal_authenticity_token, only: [:create_renewal]

  before_action :set_motor_insurance, only: [:show, :edit, :update, :destroy, :delete_document, :renew, :create_renewal, :regenerate_payout]
  before_action :load_form_data, only: [:new, :edit, :create, :update, :renew, :create_renewal]

  def index
    @current_tab = params[:tab] || 'drwise'

    # Base query
    base_query = MotorInsurance.includes(:customer, :sub_agent, :agency_code, :broker)

    # Search functionality
    if params[:search].present?
      base_query = base_query.search_motor_policies(params[:search])
    end

    # Filter by class of vehicle (Two Wheeler, Private Car, etc.)
    # Accept both :class_of_vehicle and :vehicle_type for backwards compat with old links
    class_of_vehicle_filter = params[:class_of_vehicle].presence || params[:vehicle_type].presence
    if class_of_vehicle_filter.present?
      base_query = base_query.where(class_of_vehicle: class_of_vehicle_filter)
    end

    # Filter by payment mode
    if params[:payment_mode].present?
      base_query = base_query.where(payment_mode: params[:payment_mode])
    end

    # Filter by insurance type
    if params[:insurance_type].present?
      base_query = base_query.where(insurance_type: params[:insurance_type])
    end

    # Filter by policy type
    if params[:policy_type].present?
      base_query = base_query.where(policy_type: params[:policy_type])
    end

    # Filter by vehicle number (registration number)
    if params[:vehicle_number].present?
      base_query = base_query.where("registration_number ILIKE ?", "%#{params[:vehicle_number]}%")
    end

    # Filter by insurance company
    if params[:company].present?
      base_query = base_query.where(insurance_company_name: params[:company])
    end

    # Filter by status
    if params[:status].present?
      case params[:status]
      when 'active'        then base_query = base_query.where('policy_end_date IS NULL OR policy_end_date >= ?', Date.current)
      when 'expiring_soon' then base_query = base_query.where(policy_end_date: Date.current..30.days.from_now)
      when 'expired'       then base_query = base_query.where('policy_end_date < ?', Date.current)
      end
    end

    # Filter by affiliate
    if params[:sub_agent_id].present?
      base_query = base_query.where(sub_agent_id: params[:sub_agent_id])
    end

    # Filter by policy start date range
    if params[:from_date].present?
      base_query = base_query.where("policy_start_date >= ?", params[:from_date])
    end
    if params[:to_date].present?
      base_query = base_query.where("policy_start_date <= ?", params[:to_date])
    end

    # Tab-based filtering using DrWise/Non-DrWise classification
    if @current_tab == 'drwise'
      @motor_insurances = base_query.where(
        is_admin_added: true,
        is_customer_added: false,
        is_agent_added: false
      )
    else
      @motor_insurances = base_query.where(
        '(is_customer_added = ? AND is_admin_added = ? AND is_agent_added = ?) OR (is_agent_added = ? AND is_customer_added = ? AND is_admin_added = ?)',
        true, false, false, true, false, false
      )
    end

    # Single query replaces 7+ separate count/sum queries
    row = ActiveRecord::Base.connection.execute(<<~SQL).first
      SELECT
        COUNT(*) FILTER (WHERE is_admin_added AND NOT is_customer_added AND NOT is_agent_added)                                                              AS drwise_count,
        COUNT(*) FILTER (WHERE (is_customer_added AND NOT is_admin_added AND NOT is_agent_added) OR (is_agent_added AND NOT is_customer_added AND NOT is_admin_added)) AS non_drwise_count,
        COALESCE(SUM(total_premium) FILTER (WHERE is_admin_added AND NOT is_customer_added AND NOT is_agent_added), 0)                                       AS drwise_premium,
        COALESCE(SUM(total_premium) FILTER (WHERE (is_customer_added AND NOT is_admin_added AND NOT is_agent_added) OR (is_agent_added AND NOT is_customer_added AND NOT is_admin_added)), 0) AS non_drwise_premium
      FROM motor_insurances
    SQL
    @drwise_count      = row['drwise_count'].to_i
    @non_drwise_count  = row['non_drwise_count'].to_i
    @drwise_premium    = row['drwise_premium'].to_f
    @non_drwise_premium = row['non_drwise_premium'].to_f

    # Vehicle class counts for current tab — single grouped query
    tab_where = if @current_tab == 'drwise'
      'is_admin_added = true AND is_customer_added = false AND is_agent_added = false'
    else
      '(is_customer_added = true AND is_admin_added = false AND is_agent_added = false) OR (is_agent_added = true AND is_customer_added = false AND is_admin_added = false)'
    end
    vehicle_class_counts = MotorInsurance.where(tab_where).group(:class_of_vehicle).count
    @two_wheeler_count   = vehicle_class_counts['Two Wheeler'].to_i
    @private_car_count   = vehicle_class_counts['Private Car'].to_i
    @goods_vehicle_count = vehicle_class_counts['Goods Vehicle'].to_i
    @taxi_count          = vehicle_class_counts['Taxi'].to_i

    @total_policies = @motor_insurances.count
    @total_premium  = @current_tab == 'drwise' ? @drwise_premium : @non_drwise_premium

    # Filter dropdowns — 1 pluck replaces 3 distinct queries
    motor_dropdown_data   = MotorInsurance.pluck(:insurance_company_name, :policy_type, :payment_mode, :sub_agent_id)
    @filter_companies     = motor_dropdown_data.map { |r| r[0] }.compact.uniq.reject(&:blank?).sort
    @filter_policy_types  = motor_dropdown_data.map { |r| r[1] }.compact.uniq.reject(&:blank?).sort
    @filter_payment_modes = motor_dropdown_data.map { |r| r[2] }.compact.uniq.reject(&:blank?).sort
    motor_sub_agent_ids   = motor_dropdown_data.map { |r| r[3] }.compact.uniq
    @filter_sub_agents    = SubAgent.where(id: motor_sub_agent_ids).order(:first_name, :last_name)

    @motor_insurances = paginate_records(@motor_insurances.order(policy_start_date: :desc))
  end

  def show
  end

  def new
    @motor_insurance = MotorInsurance.new(
      policy_booking_date: Date.current,
      policy_start_date: Date.current,
      policy_end_date: Date.current + 1.year,
      gst_percentage: 18.0,
      is_admin_added: true
    )
    @motor_insurance.motor_insurance_nominees.build

    # Pre-fill customer data if coming from customer page
    if params[:customer_id].present?
      @selected_customer = Customer.find(params[:customer_id])
      @motor_insurance.customer_id = @selected_customer.id

      # Auto-select customer's existing affiliate if they have one
      if @selected_customer.affiliate.present?
        @motor_insurance.sub_agent_id = @selected_customer.affiliate.id
        @auto_select_affiliate = @selected_customer.affiliate.id
      else
        # Set 'Self' as default affiliate (no sub_agent)
        @auto_select_affiliate = 'self'
      end

      # Auto-populate family members as policy holder options
      @customer_family_members = @selected_customer.family_members.includes(:customer)
    end

    # Pre-fill lead data if coming from lead conversion
    if params[:lead_id].present?
      @lead = Lead.find_by(id: params[:lead_id])
      if @lead
        # Set the lead_id for the motor insurance record
        @motor_insurance.lead_id = @lead.lead_id

        # If customer_id wasn't already set, get it from the lead
        if @selected_customer.nil? && @lead.converted_customer_id.present?
          @selected_customer = Customer.find(@lead.converted_customer_id)
          @motor_insurance.customer_id = @selected_customer.id
          @customer_family_members = @selected_customer.family_members.includes(:customer)
        end

        # Auto-fill affiliate from lead
        if @lead.affiliate_id.present?
          @motor_insurance.sub_agent_id = @lead.affiliate_id
          @auto_select_affiliate = @lead.affiliate_id
        elsif !@lead.is_direct
          @auto_select_affiliate = 'self'
        end
      end
    end
  end

  def edit
    # Load customer family members for policy holder options
    @customer_family_members = @motor_insurance.customer&.family_members&.includes(:customer)

    # Set selected customer for form
    @selected_customer = @motor_insurance.customer

    # Set auto-select affiliate based on existing sub_agent
    if @motor_insurance.sub_agent_id.present?
      @auto_select_affiliate = @motor_insurance.sub_agent_id
    else
      @auto_select_affiliate = 'self'
    end

    # Convert policy holder ID to name for proper form display
    if @customer_family_members&.any? && @motor_insurance.policy_holder.present?
      # If policy_holder is stored as family member ID, find the corresponding name
      member = @customer_family_members.find { |m| m.id.to_s == @motor_insurance.policy_holder }
      if member
        @selected_policy_holder = member.name
      else
        @selected_policy_holder = @motor_insurance.policy_holder
      end
    else
      @selected_policy_holder = @motor_insurance.policy_holder.presence || 'Self'
    end
  end

  def create
    processed_params = process_broker_params(motor_insurance_params)
    @motor_insurance = MotorInsurance.new(processed_params)

    # Set admin tracking fields for policies created from admin panel
    @motor_insurance.policy_added_by_admin = true
    @motor_insurance.is_admin_added = true
    @motor_insurance.is_customer_added = false
    @motor_insurance.is_agent_added = false

    # Auto-set affiliate from customer if not already set
    if @motor_insurance.sub_agent_id.blank? && @motor_insurance.customer_id.present?
      customer = Customer.find(@motor_insurance.customer_id)
      if customer.sub_agent_id.present?
        @motor_insurance.sub_agent_id = customer.sub_agent_id
      elsif customer.lead_id.present?
        lead = Lead.find_by(lead_id: customer.lead_id)
        @motor_insurance.sub_agent_id = lead.affiliate_id if lead&.affiliate_id.present?
      end
    end

    # Set default commission percentages if empty
    set_default_commissions(@motor_insurance)

    set_distributor_from_affiliate(@motor_insurance)

    # Validate broker_id exists before saving to prevent foreign key violation
    if @motor_insurance.broker_id.present? && !Broker.exists?(@motor_insurance.broker_id)
      Rails.logger.warn "Invalid broker_id #{@motor_insurance.broker_id} detected, clearing it"
      @motor_insurance.broker_id = nil
    end

    if @motor_insurance.save
      # Handle R2 main policy document upload
      handle_main_policy_r2_upload(@motor_insurance) if params[:motor_insurance][:main_policy_document].present?

      # Handle R2 document uploads after successful save
      handle_motor_documents_r2_upload(@motor_insurance)

      # Handle additional document uploads to R2
      handle_additional_documents_r2_upload(@motor_insurance)

      # Update lead status if this policy was created from a lead conversion
      if @motor_insurance.lead_id.present?
        lead = Lead.find_by(lead_id: @motor_insurance.lead_id)
        if lead
          # Update the lead to mark policy as created and move to converted stage
          lead.update!(
            current_stage: 'converted',
            policy_created_id: @motor_insurance.id
          )
        end
      end

      redirect_to admin_motor_insurance_path(@motor_insurance), notice: 'Motor insurance policy was successfully created.'
    else
      load_form_data
      render :new, status: :unprocessable_entity
    end
  end

  def update
    processed_params = process_broker_params(motor_insurance_params)
    @motor_insurance.assign_attributes(processed_params)
    set_distributor_from_affiliate(@motor_insurance)

    # Validate broker_id exists before saving to prevent foreign key violation
    if @motor_insurance.broker_id.present? && !Broker.exists?(@motor_insurance.broker_id)
      Rails.logger.warn "Invalid broker_id #{@motor_insurance.broker_id} detected, clearing it"
      @motor_insurance.broker_id = nil
    end

    if @motor_insurance.save
      # Handle R2 main policy document upload
      handle_main_policy_r2_upload(@motor_insurance) if params[:motor_insurance][:main_policy_document].present?

      # Handle R2 document uploads after successful save
      handle_motor_documents_r2_upload(@motor_insurance)

      # Handle additional document uploads to R2
      handle_additional_documents_r2_upload(@motor_insurance)

      redirect_to admin_motor_insurance_path(@motor_insurance), notice: 'Motor insurance policy was successfully updated.'
    else
      load_form_data
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    policy_number = @motor_insurance.policy_number
    customer_name = @motor_insurance.customer&.display_name
    vehicle_registration = @motor_insurance.registration_number

    begin
      ActiveRecord::Base.transaction do
        # 1. Delete commission payouts for this motor insurance
        CommissionPayout.where(policy_type: 'motor', policy_id: @motor_insurance.id).destroy_all

        # 2. Delete main payouts for this motor insurance
        Payout.where(policy_type: 'motor', policy_id: @motor_insurance.id).destroy_all

        # 3. Delete lead record if it was created for this policy
        if @motor_insurance.lead_id.present?
          lead = Lead.find_by(lead_id: @motor_insurance.lead_id)
          if lead && lead.policy_created_id == @motor_insurance.id
            lead.destroy
          end
        end

        # 4. Delete policy documents from R2 and database
        @motor_insurance.policy_documents_records.each do |doc|
          # Delete from R2 if file key exists
          if doc.r2_file_key.present?
            R2Service.delete_file(doc.r2_file_key) rescue Rails.logger.warn("Failed to delete R2 file: #{doc.r2_file_key}")
          end
        end

        # 5. Delete motor insurance specific documents from R2
        @motor_insurance.motor_insurance_documents.each do |doc|
          if doc.r2_file_key.present?
            R2Service.delete_file(doc.r2_file_key) rescue Rails.logger.warn("Failed to delete motor document from R2: #{doc.r2_file_key}")
          end
        end

        # 6. Delete main policy document from R2 if exists
        if @motor_insurance.main_policy_document_key.present?
          R2Service.delete_file(@motor_insurance.main_policy_document_key) rescue Rails.logger.warn("Failed to delete main policy from R2")
        end

        # 7. Delete uploaded documents from R2
        @motor_insurance.uploaded_documents.each do |doc|
          if doc.respond_to?(:file) && doc.file.attached?
            doc.file.purge rescue Rails.logger.warn("Failed to purge uploaded document")
          end
        end

        # 8. Delete the motor insurance record (this will cascade to dependent associations)
        @motor_insurance.destroy!
      end

      redirect_to admin_motor_insurances_path,
                  notice: "Motor insurance policy #{policy_number} for vehicle #{vehicle_registration} (#{customer_name}) and all associated data were successfully deleted."

    rescue => e
      Rails.logger.error "Failed to delete motor insurance #{@motor_insurance.id}: #{e.message}"
      redirect_to admin_motor_insurances_path,
                  alert: "Failed to delete motor insurance policy. Error: #{e.message}"
    end
  end

  def delete_document
    begin
      document_id = params[:document_id]
      document_type = params[:document_type]

      # Find the specific document attachment
      document = nil
      case document_type
      when 'policy_documents'
        document = @motor_insurance.policy_documents.find(document_id)
      when 'documents'
        document = @motor_insurance.documents.find(document_id)
      else
        raise "Invalid document type: #{document_type}"
      end

      if document
        document.purge
        render json: { success: true, message: 'Document deleted successfully' }
      else
        render json: { success: false, error: 'Document not found' }
      end

    rescue => e
      Rails.logger.error "Failed to delete document: #{e.message}"
      render json: { success: false, error: e.message }
    end
  end

  def renew
    @motor_insurance = MotorInsurance.find(params[:id])

    # Create a new policy with data from the existing policy
    @renewed_policy = @motor_insurance.dup

    # Set renewal-specific attributes
    @renewed_policy.policy_type = 'Renewal'
    @renewed_policy.policy_number = nil  # Will be generated new
    @renewed_policy.policy_booking_date = Date.current

    # Calculate new policy dates based on the original policy end date
    @renewed_policy.policy_start_date = @motor_insurance.policy_end_date + 1.day

    # Set end date to 1 year from new start date (motor insurance is typically annual)
    @renewed_policy.policy_end_date = @renewed_policy.policy_start_date + 1.year - 1.day

    # Clear any ID fields to ensure a new record is created
    @renewed_policy.id = nil
    @renewed_policy.created_at = nil
    @renewed_policy.updated_at = nil
    @renewed_policy.lead_id = nil

    # Copy all important fields from original policy

    # Customer & Agent Details (already copied by dup)
    # @renewed_policy.customer_id = @motor_insurance.customer_id
    # @renewed_policy.policy_holder = @motor_insurance.policy_holder
    # @renewed_policy.sub_agent_id = @motor_insurance.sub_agent_id
    # @renewed_policy.distributor_id = @motor_insurance.distributor_id
    # @renewed_policy.investor_id = @motor_insurance.investor_id

    # Vehicle Details
    @renewed_policy.registration_number = @motor_insurance.registration_number
    @renewed_policy.vehicle_type = @motor_insurance.vehicle_type
    @renewed_policy.class_of_vehicle = @motor_insurance.class_of_vehicle
    @renewed_policy.make = @motor_insurance.make
    @renewed_policy.model = @motor_insurance.model
    @renewed_policy.variant = @motor_insurance.variant
    @renewed_policy.mfy = @motor_insurance.mfy
    @renewed_policy.engine_number = @motor_insurance.engine_number
    @renewed_policy.chassis_number = @motor_insurance.chassis_number
    @renewed_policy.seating_capacity = @motor_insurance.seating_capacity

    # Policy Details
    @renewed_policy.insurance_company_name = @motor_insurance.insurance_company_name
    @renewed_policy.insurance_type = @motor_insurance.insurance_type
    @renewed_policy.broker_id = @motor_insurance.broker_id
    @renewed_policy.broker_code_type = @motor_insurance.broker_code_type
    @renewed_policy.agency_code_id = @motor_insurance.agency_code_id

    # Vehicle Values
    @renewed_policy.vehicle_idv = @motor_insurance.vehicle_idv
    @renewed_policy.cng_idv = @motor_insurance.cng_idv
    @renewed_policy.total_idv = @motor_insurance.total_idv
    @renewed_policy.ncb = @motor_insurance.ncb
    @renewed_policy.discount_loading_percent = @motor_insurance.discount_loading_percent

    # Premium Details
    @renewed_policy.net_premium = @motor_insurance.net_premium
    @renewed_policy.tp_premium = @motor_insurance.tp_premium
    @renewed_policy.gst_percentage = @motor_insurance.gst_percentage
    @renewed_policy.total_premium = @motor_insurance.total_premium

    # Commission Details
    @renewed_policy.main_agent_commission_percentage = @motor_insurance.main_agent_commission_percentage
    @renewed_policy.commission_amount = @motor_insurance.commission_amount
    @renewed_policy.tds_percentage = @motor_insurance.tds_percentage
    @renewed_policy.tds_amount = @motor_insurance.tds_amount
    @renewed_policy.after_tds_value = @motor_insurance.after_tds_value

    # Sub Agent Commission
    @renewed_policy.sub_agent_commission_percentage = @motor_insurance.sub_agent_commission_percentage
    @renewed_policy.sub_agent_commission_amount = @motor_insurance.sub_agent_commission_amount
    @renewed_policy.sub_agent_tds_percentage = @motor_insurance.sub_agent_tds_percentage
    @renewed_policy.sub_agent_tds_amount = @motor_insurance.sub_agent_tds_amount
    @renewed_policy.sub_agent_after_tds_value = @motor_insurance.sub_agent_after_tds_value

    # Distributor Commission
    @renewed_policy.distributor_commission_percentage = @motor_insurance.distributor_commission_percentage
    @renewed_policy.distributor_commission_amount = @motor_insurance.distributor_commission_amount
    @renewed_policy.distributor_tds_percentage = @motor_insurance.distributor_tds_percentage
    @renewed_policy.distributor_tds_amount = @motor_insurance.distributor_tds_amount
    @renewed_policy.distributor_after_tds_value = @motor_insurance.distributor_after_tds_value

    # Investor Commission
    @renewed_policy.investor_commission_percentage = @motor_insurance.investor_commission_percentage
    @renewed_policy.investor_commission_amount = @motor_insurance.investor_commission_amount
    @renewed_policy.investor_tds_percentage = @motor_insurance.investor_tds_percentage
    @renewed_policy.investor_tds_amount = @motor_insurance.investor_tds_amount
    @renewed_policy.investor_after_tds_value = @motor_insurance.investor_after_tds_value

    # Ambassador Commission
    @renewed_policy.ambassador_commission_percentage = @motor_insurance.ambassador_commission_percentage
    @renewed_policy.ambassador_commission_amount = @motor_insurance.ambassador_commission_amount
    @renewed_policy.ambassador_tds_percentage = @motor_insurance.ambassador_tds_percentage
    @renewed_policy.ambassador_tds_amount = @motor_insurance.ambassador_tds_amount
    @renewed_policy.ambassador_after_tds_value = @motor_insurance.ambassador_after_tds_value

    # Company & Profit
    @renewed_policy.company_expenses_percentage = @motor_insurance.company_expenses_percentage
    @renewed_policy.total_distribution_percentage = @motor_insurance.total_distribution_percentage
    @renewed_policy.profit_percentage = @motor_insurance.profit_percentage
    @renewed_policy.profit_amount = @motor_insurance.profit_amount

    # Optional Covers
    @renewed_policy.zero_depreciation = @motor_insurance.zero_depreciation
    @renewed_policy.roadside_assistance = @motor_insurance.roadside_assistance
    @renewed_policy.engine_protector = @motor_insurance.engine_protector
    @renewed_policy.key_replacement = @motor_insurance.key_replacement
    @renewed_policy.return_to_invoice = @motor_insurance.return_to_invoice
    @renewed_policy.consumable_cover = @motor_insurance.consumable_cover
    @renewed_policy.personal_accident_cover = @motor_insurance.personal_accident_cover
    @renewed_policy.legal_liability = @motor_insurance.legal_liability
    @renewed_policy.electrical_accessories = @motor_insurance.electrical_accessories
    @renewed_policy.non_electrical_accessories = @motor_insurance.non_electrical_accessories

    # Additional Details
    @renewed_policy.financier = @motor_insurance.financier
    @renewed_policy.reference_by_name = @motor_insurance.reference_by_name
    @renewed_policy.extra_note = @motor_insurance.extra_note

    # Copy nominees from original policy (dup doesn't copy associations)
    @motor_insurance.motor_insurance_nominees.each do |nominee|
      @renewed_policy.motor_insurance_nominees.build(
        nominee_name: nominee.nominee_name,
        relationship: nominee.relationship,
        age: nominee.age,
        share_percentage: nominee.share_percentage
      )
    end

    # Load form data for the view
    load_form_data

    # Pre-select customer and affiliate data
    @selected_customer = @motor_insurance.customer
    @customer_family_members = @selected_customer&.family_members&.includes(:customer)

    # Set auto-select affiliate based on existing sub_agent
    if @motor_insurance.sub_agent_id.present?
      @auto_select_affiliate = @motor_insurance.sub_agent_id
    else
      @auto_select_affiliate = 'self'
    end

    render :renew
  end

  def regenerate_payout
    existing_payout = Payout.find_by(policy_type: 'motor', policy_id: @motor_insurance.id)
    if existing_payout
      redirect_to admin_motor_insurance_path(@motor_insurance), alert: 'Payout already exists for this policy.'
      return
    end

    unless @motor_insurance.is_admin_added?
      redirect_to admin_motor_insurance_path(@motor_insurance), alert: 'Payout can only be generated for DrWise (admin-added) policies.'
      return
    end

    begin
      StructuredPayoutService.create_for_policy(@motor_insurance, 'motor')
      redirect_to admin_motor_insurance_path(@motor_insurance), notice: 'Payout generated successfully.'
    rescue => e
      Rails.logger.error "Failed to regenerate payout for motor insurance #{@motor_insurance.id}: #{e.message}"
      redirect_to admin_motor_insurance_path(@motor_insurance), alert: "Failed to generate payout: #{e.message}"
    end
  end

  def create_renewal
    # Process broker params if needed
    processed_params = process_broker_params(motor_insurance_params)
    @renewed_policy = MotorInsurance.new(processed_params)

    # Set admin tracking fields for renewal policies
    @renewed_policy.policy_added_by_admin = true
    @renewed_policy.is_admin_added = true
    @renewed_policy.is_customer_added = false
    @renewed_policy.is_agent_added = false
    @renewed_policy.policy_type = 'Renewal'

    # Preserve company name from original policy if the (disabled) select didn't submit one
    @renewed_policy.insurance_company_name ||= @motor_insurance.insurance_company_name

    # Set default commission percentages if empty
    set_default_commissions(@renewed_policy)

    set_distributor_from_affiliate(@renewed_policy)

    if @renewed_policy.save
      redirect_to admin_motor_insurance_path(@renewed_policy),
                  notice: 'Motor insurance renewal policy was successfully created.'
    else
      # Set original policy for error recovery
      @motor_insurance = MotorInsurance.find(params[:id]) if params[:id].present?
      @selected_customer = @renewed_policy.customer
      @customer_family_members = @selected_customer&.family_members&.includes(:customer)

      # Set auto-select affiliate
      if @renewed_policy.sub_agent_id.present?
        @auto_select_affiliate = @renewed_policy.sub_agent_id
      else
        @auto_select_affiliate = 'self'
      end

      render :renew, status: :unprocessable_entity
    end
  end

  def customer_family_members
    customer_id = params[:customer_id]
    if customer_id.present?
      begin
        customer = Customer.find(customer_id)
        family_members = customer.family_members.includes(:customer)
        # Build policy holder options
        policy_holder_options = [{ value: 'Self', text: 'Self' }]
        family_members.each do |member|
          # Only add if member has a valid name and it's not empty/numeric only
          if member.name.present? && member.name.strip.length > 0 && !member.name.strip.match?(/^\d+$/)
            display_name = "#{member.name} (#{member.relationship.humanize})"
            # Use name as value, display name as text - this ensures the database stores just the name
            policy_holder_options << {
              value: member.name,
              text: display_name
            }
          end
        end

        render json: {
          success: true,
          options: policy_holder_options,
          customer_name: customer.display_name
        }
      rescue => e
        render json: {
          success: false,
          error: 'Unable to load family members'
        }
      end
    else
      render json: {
        success: false,
        error: 'Customer ID is required'
      }
    end
  end

  def policy_holder_options
    customer = Customer.find(params[:customer_id]) if params[:customer_id].present?
    options = [['Self', 'Self']]
    if customer&.family_members&.any?
      customer.family_members.each do |member|
        # Return member name as value, not ID
        display_name = "#{member.name} (#{member.relationship.humanize})"
        options << [display_name, member.name]
      end
    end
    render json: { options: options }
  end

  # AJAX endpoint for getting customer affiliate information
  def customer_affiliate_info
    customer = Customer.find(params[:customer_id]) if params[:customer_id].present?

    response = {
      customer_name: customer&.display_name,
      affiliate_id: nil,
      affiliate_name: nil
    }

    if customer&.sub_agent_id.present?
      sub_agent = SubAgent.find_by(id: customer.sub_agent_id)
      if sub_agent
        response[:affiliate_id] = sub_agent.id
        response[:affiliate_name] = sub_agent.display_name
      end
    end

    render json: response
  end

  # API endpoints for dynamic dropdowns
  def agency_codes_for_broker_type
    broker_type = params[:broker_type]

    case broker_type
    when 'direct'
      # FLOW 1: Direct mode - Fetch agents for motor insurance
      # API response format: { agent1: company_name_1, agent2: company_name_2 }
      agency_codes = AgencyCode.where('insurance_type ILIKE ?', '%motor%')
                               .select(:id, :agent_name, :code, :company_name)
                               .order(:agent_name)

      # Transform to required format for dropdown
      agents_data = agency_codes.map { |ac|
        {
          id: ac.id,
          text: ac.agent_name,  # Show only agent name in dropdown
          agent_name: ac.agent_name,
          code: ac.code,
          company_name: ac.company_name
        }
      }

      render json: {
        success: true,
        data: agents_data
      }

    when 'broking'
      # FLOW 2: Broking mode - Fetch all active broker codes for motor insurance
      # One entry per broker code so brokers with multiple codes all appear
      broker_codes = BrokerCode.includes(:broker).active.joins(:broker).order('brokers.name, broker_codes.broker_code')

      brokers_data = broker_codes.map { |bc|
        {
          id: bc.id,
          text: "#{bc.broker.name} - #{bc.broker_code}",
          broker_name: bc.broker.name,
          code: bc.broker_code
        }
      }

      render json: {
        success: true,
        data: brokers_data
      }

    else
      render json: { success: false, message: 'Invalid broker type. Use "direct" or "broking".' }
    end
  end

  # API endpoint for getting company name by agent selection (Direct mode only)
  def company_name_by_agent
    agency_code_id = params[:agency_code_id]

    if agency_code_id.present?
      agency_code = AgencyCode.find_by(id: agency_code_id)

      if agency_code
        # Get all companies for this agent name in motor insurance
        agent_name = agency_code.agent_name
        company_names = AgencyCode.where(
          agent_name: agent_name
        ).where('insurance_type ILIKE ?', '%motor%').pluck(:company_name).compact.uniq

        if company_names.length == 1
          # Single company - return as before for compatibility
          render json: {
            success: true,
            data: {
              company_name: company_names.first,
              agent_name: agent_name
            }
          }
        else
          # Multiple companies - return all options
          render json: {
            success: true,
            data: {
              company_names: company_names,
              agent_name: agent_name,
              multiple_companies: true
            }
          }
        end
      else
        render json: { success: false, message: 'Agency code not found' }
      end
    else
      render json: { success: false, message: 'Agency code ID is required' }
    end
  end

  # API endpoint for insurance companies (independent for Broking mode)
  def insurance_companies_for_type
    # FLOW 2: Broking mode - Fetch all motor insurance companies
    # API response format: { company1, company2 }

    # For motor insurance, use the motor/general insurance companies
    companies = InsuranceCompany.where(insurance_type: "motor_other").order('LOWER(name) ASC').pluck(:name)

    companies_data = companies.map { |name|
      {
        id: name,
        text: name
      }
    }

    render json: {
      success: true,
      data: companies_data
    }
  end

  # API endpoint for getting insurance companies by agency code
  def insurance_companies_by_agency
    broker_code = params[:broker_code]
    agency_code_id = params[:agency_code_id]

    if broker_code.blank? || agency_code_id.blank?
      render json: {
        success: false,
        message: 'Broker code and agency code ID are required'
      }
      return
    end

    companies_data = []

    case broker_code
    when 'direct'
      # For direct mode: Get companies mapped to the selected agency
      company_names = AgencyCode.where(
        id: agency_code_id
      ).where('insurance_type ILIKE ?', '%motor%').pluck(:company_name).compact.uniq

      if company_names.any?
        # Find insurance companies with fuzzy matching
        all_insurance_companies = InsuranceCompany.where('insurance_type ILIKE ?', '%general%')
        matching_companies = []

        company_names.each do |agency_company_name|
          # Try exact match first
          exact_match = all_insurance_companies.find_by(name: agency_company_name)
          if exact_match
            matching_companies << exact_match
          else
            # Try fuzzy matching - look for companies that contain similar words
            agency_words = agency_company_name.downcase.split.reject { |w| w.length < 4 }
            fuzzy_matches = all_insurance_companies.select do |company|
              company_words = company.name.downcase.split.reject { |w| w.length < 4 }
              # Check if main company words match (require at least 2 significant word matches)
              common_words = agency_words & company_words
              common_words.length >= 2 ||
              (agency_words.include?('bajaj') && company_words.include?('bajaj')) ||
              (agency_words.include?('tata') && company_words.include?('tata')) ||
              (agency_words.include?('hdfc') && company_words.include?('hdfc'))
            end
            matching_companies.concat(fuzzy_matches)
          end
        end

        companies_data = matching_companies.uniq.map do |company|
          {
            id: company.id,
            name: company.name
          }
        end
      end

    when 'broking'
      # For broking mode: Show all motor insurance companies
      insurance_companies = InsuranceCompany.where('insurance_type ILIKE ?', '%general%')

      companies_data = insurance_companies.map do |company|
        {
          id: company.id,
          name: company.name
        }
      end

    else
      render json: {
        success: false,
        message: 'Invalid broker code. Use "direct" or "broking".'
      }
      return
    end

    render json: {
      success: true,
      data: companies_data
    }
  end

  # API endpoint for loading customer nominees
  def load_customer_nominees
    customer_id = params[:customer_id]

    if customer_id.present?
      begin
        customer = Customer.find(customer_id)
        nominee_options = []

        # Include customer's own registered nominee first
        if customer.nominee_name.present?
          age = if customer.nominee_date_of_birth.present?
            ((Date.today - customer.nominee_date_of_birth) / 365.25).floor
          else
            0
          end
          nominee_options << {
            nominee_name: customer.nominee_name,
            relationship: customer.nominee_relation&.downcase || 'other',
            age: age
          }
        end

        # Add family members (skip if already added as primary nominee)
        customer.family_members.each do |member|
          next unless member.name.present? && member.name.strip.length > 0 && !member.name.strip.match?(/^\d+$/)
          next if customer.nominee_name.present? && member.name.strip.downcase == customer.nominee_name.strip.downcase

          nominee_options << {
            nominee_name: member.name,
            relationship: member.relationship&.downcase || 'other',
            age: member.age || 0
          }
        end

        render json: {
          success: true,
          nominees: nominee_options,
          customer_name: customer.display_name
        }
      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          message: 'Customer not found',
          nominees: []
        }
      end
    else
      render json: {
        success: false,
        message: 'Customer ID is required',
        nominees: []
      }
    end
  end

  # GET /admin/insurance/motor/download
  def download
    format_type = params[:format_type]
    scope = build_motor_filtered_scope.order(created_at: :desc)

    case format_type
    when 'csv'
      send_data generate_motor_csv(scope),
                filename: "motor_insurance_#{Date.current}.csv", type: 'text/csv'
    when 'excel'
      send_data generate_motor_excel(scope),
                filename: "motor_insurance_#{Date.current}.xlsx",
                type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    else
      redirect_to admin_motor_insurances_path, alert: 'Invalid download format.'
    end
  end

  private

  def build_motor_filtered_scope
    scope = MotorInsurance.includes(:customer, :sub_agent)
    current_tab = params[:tab] || 'drwise'
    if current_tab == 'drwise'
      scope = scope.where(is_admin_added: true, is_customer_added: false, is_agent_added: false)
    else
      scope = scope.where(
        '(is_customer_added = ? AND is_admin_added = ? AND is_agent_added = ?) OR (is_agent_added = ? AND is_customer_added = ? AND is_admin_added = ?)',
        true, false, false, true, false, false
      )
    end
    scope = scope.search_motor_policies(params[:search]) if params[:search].present?
    class_of_vehicle_filter = params[:class_of_vehicle].presence || params[:vehicle_type].presence
    scope = scope.where(class_of_vehicle: class_of_vehicle_filter) if class_of_vehicle_filter.present?
    scope = scope.where(payment_mode: params[:payment_mode])    if params[:payment_mode].present?
    scope = scope.where(policy_type: params[:policy_type])      if params[:policy_type].present?
    scope = scope.where(insurance_company_name: params[:company]) if params[:company].present?
    scope = scope.where(sub_agent_id: params[:sub_agent_id])    if params[:sub_agent_id].present?
    scope = scope.where("registration_number ILIKE ?", "%#{params[:vehicle_number]}%") if params[:vehicle_number].present?
    if params[:status].present?
      case params[:status]
      when 'active'        then scope = scope.where('policy_end_date IS NULL OR policy_end_date >= ?', Date.current)
      when 'expiring_soon' then scope = scope.where(policy_end_date: Date.current..30.days.from_now)
      when 'expired'       then scope = scope.where('policy_end_date < ?', Date.current)
      end
    end
    scope = scope.where("policy_start_date >= ?", params[:from_date]) if params[:from_date].present?
    scope = scope.where("policy_start_date <= ?", params[:to_date])   if params[:to_date].present?
    scope
  end

  def generate_motor_csv(records)
    require 'csv'
    CSV.generate(headers: true) do |csv|
      csv << %w[ID PolicyNumber PolicyType VehicleRegistration ClassOfVehicle
                CustomerName CustomerEmail InsuranceCompany TotalIDV TotalPremium
                NetPremium PaymentMode PolicyStartDate PolicyEndDate Status Source
                Affiliate BookingDate CreatedAt]
      records.find_each do |p|
        source = if p.is_admin_added? then 'Admin' elsif p.is_agent_added? then 'Agent' elsif p.is_customer_added? then 'Customer' else 'Unknown' end
        csv << [p.id, p.policy_number, p.policy_type, p.registration_number, p.class_of_vehicle,
                p.customer&.display_name, p.customer&.email, p.insurance_company_name,
                p.total_idv, p.total_premium, p.net_premium, p.payment_mode,
                p.policy_start_date, p.policy_end_date, p.status, source,
                p.sub_agent&.display_name, p.policy_booking_date, p.created_at.strftime('%Y-%m-%d %H:%M:%S')]
      end
    end
  end

  def generate_motor_excel(records)
    require 'caxlsx'
    package = Axlsx::Package.new
    wb = package.workbook
    hdr = wb.styles.add_style(bg_color: 'BF360C', fg_color: 'FFFFFF', b: true, alignment: { horizontal: :center })
    row = wb.styles.add_style(alignment: { horizontal: :left })
    wb.add_worksheet(name: 'Motor Insurance') do |sheet|
      sheet.add_row %w[ID PolicyNumber PolicyType VehicleRegistration ClassOfVehicle
                       CustomerName CustomerEmail InsuranceCompany TotalIDV TotalPremium
                       NetPremium PaymentMode PolicyStartDate PolicyEndDate Status Source
                       Affiliate BookingDate CreatedAt], style: hdr
      records.find_each do |p|
        source = if p.is_admin_added? then 'Admin' elsif p.is_agent_added? then 'Agent' elsif p.is_customer_added? then 'Customer' else 'Unknown' end
        sheet.add_row [p.id, p.policy_number, p.policy_type, p.registration_number, p.class_of_vehicle,
                       p.customer&.display_name, p.customer&.email, p.insurance_company_name,
                       p.total_idv.to_f, p.total_premium.to_f, p.net_premium.to_f, p.payment_mode,
                       p.policy_start_date&.to_s, p.policy_end_date&.to_s, p.status, source,
                       p.sub_agent&.display_name, p.policy_booking_date&.to_s, p.created_at.strftime('%Y-%m-%d %H:%M:%S')], style: row
      end
    end
    package.to_stream.read
  end

  def process_broker_params(params)
    # Handle agency_code_id when it contains broker_X format (X is BrokerCode.id)
    if params[:agency_code_id].present? && params[:agency_code_id].start_with?('broker_')
      broker_code_id = params[:agency_code_id].gsub('broker_', '').to_i
      if broker_code_id > 0
        broker_code = BrokerCode.find_by(id: broker_code_id)
        params[:broker_id] = broker_code ? broker_code.broker_id : nil
        params[:agency_code_id] = nil
      end
    end
    params
  end

  def set_motor_insurance
    @motor_insurance = MotorInsurance.includes(:customer, :sub_agent, :agency_code, :broker).find(params[:id])
  end

  def load_form_data
    @customers = Customer.active.order(:first_name, :last_name, :company_name)
    @sub_agents = SubAgent.active.order(:first_name, :last_name)
    @distributors = Distributor.active.order(:first_name, :last_name)
    @investors = Investor.active.order(:first_name, :last_name)
    @agency_codes = AgencyCode.where(insurance_type: 'Motor Insurance')
    @brokers = Broker.active.order(:name)
    # Load all insurance companies for motor insurance
    @insurance_companies = InsuranceCompany.where('insurance_type ILIKE ? OR insurance_type ILIKE ?', '%general%', '%motor%')
                                          .order(:name)
                                          .pluck(:name)
                                          .uniq

    # Ensure the current policy's company is always available (in case it's not general/motor-typed in the DB)
    if @motor_insurance&.insurance_company_name.present?
      unless @insurance_companies.include?(@motor_insurance.insurance_company_name)
        @insurance_companies = (@insurance_companies + [@motor_insurance.insurance_company_name]).sort
      end
    end

    @vehicle_types = MotorInsurance::VEHICLE_TYPES
    @class_of_vehicles = MotorInsurance::CLASS_OF_VEHICLES
    @insurance_types = MotorInsurance::INSURANCE_TYPES
    @policy_types = MotorInsurance::POLICY_TYPES
    @payout_options = MotorInsurance::PAYOUT_OPTIONS
  end

  def motor_insurance_params
    params.require(:motor_insurance).permit(
      # Client & Agent Details
      :customer_id, :policy_holder, :sub_agent_id, :distributor_id, :investor_id, :reference_by_name,

      # Policy Details
      :insurance_company_name, :agency_code_id, :broker_id, :broker_code_type, :vehicle_type,
      :class_of_vehicle, :insurance_type, :policy_type, :policy_booking_date,
      :policy_start_date, :policy_end_date, :policy_number, :registration_number,
      :registration_date, :tp_premium, :net_premium, :gst_percentage, :total_premium,
      :payment_mode, :installment_autopay_start_date, :installment_autopay_end_date,

      # Vehicle Details
      :vehicle_idv, :cng_idv, :total_idv, :engine_number, :chassis_number,
      :mfy, :make, :model, :variant, :seating_capacity, :ncb, :discount_loading_percent,

      # Advance Details
      :broker_name, :previous_policy_number, :extra_note,

      # Commission Details
      :payout_od, :payout_tp, :payout_net, :main_agent_commission_percent,
      :main_agent_commission_amount, :main_agent_tds_percentage, :main_agent_tds_amount,
      :after_tds_value,

      # Enhanced Commission Structure
      :main_agent_commission_percentage, :commission_amount, :tds_percentage, :tds_amount,
      :sub_agent_commission_percentage, :sub_agent_commission_amount, :sub_agent_tds_percentage,
      :sub_agent_tds_amount, :sub_agent_after_tds_value,
      :distributor_commission_percentage, :distributor_commission_amount, :distributor_tds_percentage,
      :distributor_tds_amount, :distributor_after_tds_value,
      :investor_commission_percentage, :investor_commission_amount, :investor_tds_percentage,
      :investor_tds_amount, :investor_after_tds_value,
      :ambassador_commission_percentage, :ambassador_commission_amount, :ambassador_tds_percentage,
      :ambassador_tds_amount, :ambassador_after_tds_value,
      :total_distribution_percentage, :company_expenses_percentage, :company_expenses_amount, :profit_percentage, :profit_amount,

      # Legal Liability & Optional Covers
      :legal_liability, :electrical_accessories, :non_electrical_accessories,
      :zero_depreciation, :roadside_assistance, :engine_protector, :key_replacement,
      :return_to_invoice, :consumable_cover, :personal_accident_cover, :financier,

      # File Uploads - Main policy document for R2 storage
      :main_policy_document,
      # Nominees
      motor_insurance_nominees_attributes: [:id, :nominee_name, :relationship, :age, :share_percentage, :_destroy]
    )
  end

  def set_default_commissions(insurance_record)
    # Set default commission percentages if they are empty or zero
    commission_fields = {
      ambassador_commission_percentage: 2.0,
      investor_commission_percentage: 2.0,
      distributor_commission_percentage: 2.0,
      company_expenses_percentage: 2.0
    }

    commission_fields.each do |field, default_value|
      current_value = insurance_record.send(field)
      if current_value.blank? || current_value.to_f == 0.0
        insurance_record.send("#{field}=", default_value)
      end
    end

    # Ensure main agent commission has a minimum default
    if insurance_record.main_agent_commission_percentage.blank? || insurance_record.main_agent_commission_percentage.to_f == 0.0
      insurance_record.main_agent_commission_percentage = 15.0
    end

    # Ensure sub agent commission has a minimum default
    if insurance_record.sub_agent_commission_percentage.blank? || insurance_record.sub_agent_commission_percentage.to_f == 0.0
      insurance_record.sub_agent_commission_percentage = 3.0
    end
  rescue StandardError => e
    # Log error but don't fail the form submission
    Rails.logger.error "Failed to set default commissions: #{e.message}"
  end

  def set_distributor_from_affiliate(insurance_record)
    # If affiliate is selected but distributor is not set, auto-assign distributor
    if insurance_record.sub_agent_id.present? && insurance_record.distributor_id.blank?
      sub_agent = SubAgent.find(insurance_record.sub_agent_id)

      # Use direct distributor relationship first, then fall back to assignment
      distributor_id = sub_agent.distributor_id || sub_agent.assigned_distributor&.id

      insurance_record.distributor_id = distributor_id if distributor_id.present?
    end
  rescue StandardError => e
    # Log error but don't fail the form submission
    Rails.logger.error "Failed to set distributor from affiliate: #{e.message}"
  end

  def verify_renewal_authenticity_token
    # Custom CSRF token verification for renewal actions
    # This provides more lenient handling than the default Rails protection
    begin
      verify_authenticity_token
    rescue ActionController::InvalidAuthenticityToken
      # Log the error but don't halt execution
      Rails.logger.warn "CSRF token verification failed for renewal action. Proceeding with manual verification."

      # Check if the request is valid based on other criteria
      if request.post? && params[:motor_insurance].present? && current_user.present?
        # Allow the request to proceed as it appears legitimate
        Rails.logger.info "Allowing renewal request to proceed based on manual verification."
      else
        # Re-raise the error if it doesn't meet basic legitimacy criteria
        raise ActionController::InvalidAuthenticityToken
      end
    end
  end

  # Handle Motor Insurance documents R2 upload (Document Management System entries)
  def handle_motor_documents_r2_upload(motor_insurance)
    uploaded_count = 0
    failed_count = 0

    # Use raw request params to bypass ActionController::Parameters filtering for file uploads
    raw_motor_params = request.params['motor_insurance'] || {}
    doc_entries = raw_motor_params['motor_insurance_documents_attributes'] || {}

    return { uploaded: 0, failed: 0 } if doc_entries.blank?

    Rails.logger.info "Starting DMS document upload for motor insurance #{motor_insurance.id}: #{doc_entries.keys.size} entries"

    doc_entries.each do |key, doc_attrs|
      next if doc_attrs['_destroy'] == 'true'

      file = doc_attrs['file']
      next if file.blank? || !file.respond_to?(:original_filename)

      Rails.logger.info "Uploading DMS document #{key}: #{file.original_filename}"

      begin
        result = R2Service.upload(file, folder: "motor_insurance/#{motor_insurance.id}/documents")

        if result && result[:key] && !result[:error]
          doc_to_save = {
            document_type: doc_attrs['document_type'].presence || 'other',
            title: doc_attrs['title'].presence || file.original_filename,
            description: doc_attrs['description'],
            r2_file_key: result[:key],
            r2_filename: result[:filename],
            r2_content_type: result[:content_type],
            r2_file_size: result[:size],
            r2_url: result[:public_url]
          }
          motor_insurance.motor_insurance_documents.create!(doc_to_save)
          uploaded_count += 1
          Rails.logger.info "Uploaded DMS document: #{result[:filename]}"
        else
          Rails.logger.error "R2 upload failed for DMS document #{key}: #{result[:error]}"
          failed_count += 1
        end
      rescue => e
        Rails.logger.error "Error uploading DMS document #{key}: #{e.message}"
        failed_count += 1
      end
    end

    Rails.logger.info "DMS upload complete: #{uploaded_count} uploaded, #{failed_count} failed" if uploaded_count > 0 || failed_count > 0
    { uploaded: uploaded_count, failed: failed_count }
  end

  # R2 Upload Helper for main policy document
  def handle_main_policy_r2_upload(motor_insurance)
    # Use raw request params to get the file upload reliably
    file = request.params.dig('motor_insurance', 'main_policy_document')
    file ||= params[:motor_insurance][:main_policy_document]
    return unless file.present? && file.respond_to?(:original_filename)

    begin
      result = motor_insurance.upload_main_policy_to_r2(file)

      if result && result[:key] && !result[:error]
        Rails.logger.info "Main policy document uploaded: #{result[:filename]}"
      else
        error_msg = result.is_a?(Hash) ? (result[:error] || 'Unknown error') : 'Upload failed'
        Rails.logger.error "Main policy document upload failed: #{error_msg}"
        flash[:alert] = (flash[:alert] || '') + " Main policy document upload failed: #{error_msg}"
      end
    rescue => e
      Rails.logger.error "Error uploading main policy document: #{e.message}"
      flash[:alert] = (flash[:alert] || '') + " Main policy document upload failed: #{e.message}"
    end
  end

  # R2 Upload Helper for additional documents (the "Additional Documents Optional" field)
  def handle_additional_documents_r2_upload(motor_insurance)
    uploaded_count = 0
    failed_count = 0

    # Use raw request params to bypass ActionController::Parameters filtering for file upload arrays
    raw_motor_params = request.params['motor_insurance'] || {}

    # Collect files from both possible field names
    files = []
    raw_docs = raw_motor_params['documents']
    if raw_docs.present?
      files += raw_docs.is_a?(Array) ? raw_docs : [raw_docs]
    end
    raw_policy_docs = raw_motor_params['policy_documents']
    if raw_policy_docs.present?
      files += raw_policy_docs.is_a?(Array) ? raw_policy_docs : [raw_policy_docs]
    end

    files.each do |file|
      next if file.blank? || !file.respond_to?(:original_filename)

      begin
        result = R2Service.upload(file, folder: "motor_insurance/#{motor_insurance.id}/additional_documents")

        if result && result[:key] && !result[:error]
          motor_insurance.motor_insurance_documents.create!(
            document_type: 'additional_document',
            title: file.original_filename,
            description: 'Additional document',
            r2_file_key: result[:key],
            r2_filename: result[:filename],
            r2_content_type: result[:content_type],
            r2_file_size: result[:size],
            r2_url: result[:public_url]
          )
          uploaded_count += 1
          Rails.logger.info "Uploaded additional document: #{file.original_filename}"
        else
          Rails.logger.error "R2 upload failed for additional document: #{result[:error]}"
          failed_count += 1
        end
      rescue => e
        Rails.logger.error "Error uploading additional document: #{e.message}"
        failed_count += 1
      end
    end

    if failed_count > 0
      flash[:alert] = (flash[:alert] || '') + " #{failed_count} additional document(s) failed to upload."
    end
  end
end