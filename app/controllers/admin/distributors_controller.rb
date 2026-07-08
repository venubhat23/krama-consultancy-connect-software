class Admin::DistributorsController < Admin::ApplicationController
  include ConfigurablePagination
  before_action :set_distributor, only: [:show, :edit, :update, :destroy]

  # GET /admin/distributors
  def index
    @distributors = Distributor.includes(:distributor_assignments, :distributor_documents,
                                         profile_image_attachment: :blob)

    if params[:search].present?
      @distributors = @distributors.search_by_name_mobile_email(params[:search])
    end

    case params[:status]
    when 'active'   then @distributors = @distributors.active
    when 'inactive' then @distributors = @distributors.inactive
    end

    @total_filtered_count = @distributors.count

    @distributors = paginate_records(@distributors.order(created_at: :desc))

    # All three stats in one query instead of three separate count queries
    stats = ActiveRecord::Base.connection.execute(<<~SQL).first
      SELECT COUNT(*) AS total,
             COUNT(*) FILTER (WHERE status = 0) AS active_count,
             COUNT(*) FILTER (WHERE status = 1) AS inactive_count
      FROM distributors
    SQL
    @total_distributors    = stats['total'].to_i
    @active_distributors   = stats['active_count'].to_i
    @inactive_distributors = stats['inactive_count'].to_i

    # Precompute sub-agent counts to avoid N+1 in view
    distributor_ids    = @distributors.map(&:id)
    @sub_agent_counts  = DistributorAssignment.where(distributor_id: distributor_ids)
                                              .group(:distributor_id)
                                              .count
  end

  # GET /admin/distributors/1
  def show
    @documents = @distributor.distributor_documents.order(:created_at)

    # Get assigned affiliates with their detailed information
    @assigned_affiliates = @distributor.assigned_sub_agents.includes(
      :distributor_assignment
    ).order('sub_agents.created_at DESC')

    # Batch-calculate stats for all affiliates in ~6 queries instead of N*15
    @affiliate_stats = batch_calculate_affiliate_stats(@assigned_affiliates.to_a)

    # Get actual distributor payout data
    @distributor_payout_data = calculate_single_distributor_payouts(@distributor.id)

    # Overall distributor statistics (excluding commission calculation)
    @distributor_stats = calculate_distributor_stats_basic

    # Build commission ledger
    @ledger_entries = build_distributor_ledger(@distributor)
    @ledger_closing_balance = @ledger_entries.last&.dig(:balance) || 0.0
  end

  # GET /admin/distributors/new
  def new
    @distributor = Distributor.new
    @distributor.role_id = 'distributor'
    @distributor.distributor_documents.build
    @investors = Investor.all
  end

  # GET /admin/distributors/1/edit
  def edit
    # Documents are already loaded via set_distributor before_action
    @distributor.distributor_documents.build if @distributor.distributor_documents.empty?
    @investors = Investor.all
    # Preload assigned sub_agents to avoid N+1 queries
    @assigned_sub_agent_ids = @distributor.assigned_sub_agents.pluck(:id).to_set
  end

  # POST /admin/distributors
  def create
    Rails.logger.info "=== DISTRIBUTOR CREATE PARAMS ==="
    Rails.logger.info "Documents attributes: #{params[:distributor][:distributor_documents_attributes].inspect}"
    Rails.logger.info "Assigned affiliate IDs from params: #{params[:distributor][:assigned_affiliate_ids].inspect}"

    # Extract permitted parameters
    permitted_params = distributor_params
    assigned_affiliate_ids = permitted_params.delete(:assigned_affiliate_ids)

    # Handle upload_main_document separately to avoid ActiveStorage issues
    main_document = permitted_params.delete(:upload_main_document)

    # Handle profile_image separately for R2 upload
    profile_image = permitted_params.delete(:profile_image)

    # Process document files before creating distributor
    documents_attributes = permitted_params[:distributor_documents_attributes]
    if documents_attributes.present?
      documents_attributes.each do |key, doc_attrs|
        if doc_attrs[:document_file].present?
          # Store the file in the document attributes for processing by the model
          # The DistributorDocument model will handle the R2 upload in its before_save callback
        end
      end
    end

    @distributor = Distributor.new(permitted_params)
    @distributor.role_id = 'distributor'

    if @distributor.save
      # Attach main document after distributor is saved
      if main_document.present?
        begin
          @distributor.upload_main_document.attach(main_document)
        rescue => e
          Rails.logger.error "Failed to attach main document: #{e.message}"
          # Don't fail the whole creation for document attachment issues
        end
      end

      # Handle profile image upload to R2
      handle_profile_image_upload(@distributor, permitted_params[:profile_image])

      # Create user account for ambassador login (same logic as customers)
      create_ambassador_user_account(@distributor)
      handle_affiliate_assignments(@distributor, assigned_affiliate_ids)
      Rails.logger.info "Documents after create: #{@distributor.distributor_documents.count}"
      redirect_to admin_distributors_path, notice: 'Ambassador was successfully created with login credentials.'
    else
      Rails.logger.error "Create errors: #{@distributor.errors.full_messages}"
      @distributor.distributor_documents.build if @distributor.distributor_documents.empty?
      @investors = Investor.all  # Reload investors for form rendering
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /admin/distributors/1
  def update
    Rails.logger.info "=== DISTRIBUTOR UPDATE PARAMS ==="
    Rails.logger.info "Documents attributes: #{params[:distributor][:distributor_documents_attributes].inspect}"
    Rails.logger.info "Assigned affiliate IDs from params: #{params[:distributor][:assigned_affiliate_ids].inspect}"

    # Extract permitted parameters
    permitted_params = distributor_params
    assigned_affiliate_ids = permitted_params.delete(:assigned_affiliate_ids)

    # Handle upload_main_document separately to avoid ActiveStorage issues
    main_document = permitted_params.delete(:upload_main_document)

    # Handle profile_image separately for R2 upload
    profile_image = permitted_params.delete(:profile_image)

    if @distributor.update(permitted_params)
      # Attach main document after distributor is updated
      if main_document.present?
        begin
          @distributor.upload_main_document.attach(main_document)
        rescue => e
          Rails.logger.error "Failed to attach main document during update: #{e.message}"
          # Don't fail the whole update for document attachment issues
        end
      end

      # Handle profile image upload to R2
      handle_profile_image_upload(@distributor, profile_image)

      handle_affiliate_assignments(@distributor, assigned_affiliate_ids)
      Rails.logger.info "Documents after update: #{@distributor.distributor_documents.count}"
      redirect_to admin_distributors_path, notice: 'Ambassador was successfully updated.'
    else
      Rails.logger.error "Update errors: #{@distributor.errors.full_messages}"
      @distributor.distributor_documents.build if @distributor.distributor_documents.empty?
      @investors = Investor.all  # Reload investors for form rendering
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/distributors/1
  def destroy
    # Check for relationships that would prevent deletion
    has_assigned_affiliates = @distributor.assigned_sub_agents.exists?
    has_direct_affiliates = @distributor.sub_agents.exists?

    # Check for insurance policies directly linked to this distributor
    has_health_policies = HealthInsurance.where(distributor_id: @distributor.id).exists? rescue false
    has_life_policies = LifeInsurance.where(distributor_id: @distributor.id).exists? rescue false
    has_motor_policies = MotorInsurance.where(distributor_id: @distributor.id).exists? rescue false
    has_other_policies = defined?(OtherInsurance) && OtherInsurance.where(distributor_id: @distributor.id).exists? rescue false

    # Check for distributor payouts
    has_payouts = defined?(DistributorPayout) && DistributorPayout.where(distributor_id: @distributor.id).exists? rescue false

    if has_assigned_affiliates || has_direct_affiliates || has_health_policies || has_life_policies || has_motor_policies || has_other_policies || has_payouts
      error_messages = []

      if has_assigned_affiliates || has_direct_affiliates
        affiliate_count = @distributor.assigned_sub_agents.count + @distributor.sub_agents.count
        error_messages << "#{affiliate_count} assigned affiliate(s)"
      end

      policy_count = 0
      policy_count += HealthInsurance.where(distributor_id: @distributor.id).count rescue 0
      policy_count += LifeInsurance.where(distributor_id: @distributor.id).count rescue 0
      policy_count += MotorInsurance.where(distributor_id: @distributor.id).count rescue 0
      policy_count += OtherInsurance.where(distributor_id: @distributor.id).count rescue 0 if defined?(OtherInsurance)

      if policy_count > 0
        error_messages << "#{policy_count} insurance policy(ies)"
      end

      if has_payouts
        payout_count = DistributorPayout.where(distributor_id: @distributor.id).count rescue 0
        error_messages << "#{payout_count} payout record(s)" if payout_count > 0
      end

      message = "Cannot delete ambassador with #{error_messages.join(', ')}. Please reassign or remove these records first."
      redirect_to admin_distributors_path, alert: message
    else
      begin
        # Delete associated records that don't have proper cascade setup
        @distributor.distributor_documents.destroy_all
        @distributor.distributor_assignments.destroy_all

        # Now destroy the distributor
        @distributor.destroy!
        redirect_to admin_distributors_path, notice: 'Ambassador was successfully deleted.'
      rescue => e
        redirect_to admin_distributors_path,
                    alert: "Failed to delete ambassador: #{e.message}"
      end
    end
  end

  # PATCH /admin/distributors/1/toggle_status
  def toggle_status
    @distributor = Distributor.find(params[:id])
    new_status = @distributor.active? ? :inactive : :active

    if @distributor.update(status: new_status)
      redirect_to admin_distributors_path, notice: "Distributor status updated to #{new_status}."
    else
      redirect_to admin_distributors_path, alert: 'Failed to update status.'
    end
  end

  # PATCH /admin/distributors/1/deactivate
  def deactivate
    @distributor = Distributor.find(params[:id])
    if @distributor.deactivate!
      redirect_to admin_distributors_path, notice: 'Ambassador was successfully deactivated.'
    else
      redirect_to admin_distributors_path, alert: 'Failed to deactivate ambassador.'
    end
  end

  # PATCH /admin/distributors/1/activate
  def activate
    @distributor = Distributor.find(params[:id])
    if @distributor.activate!
      redirect_to admin_distributors_path, notice: 'Ambassador was successfully activated.'
    else
      redirect_to admin_distributors_path, alert: 'Failed to activate ambassador.'
    end
  end

  # GET /admin/distributors/download
  def download
    format_type = params[:format_type]

    scope = Distributor.all
    scope = scope.search_by_name_mobile_email(params[:search]) if params[:search].present?
    scope = case params[:status]
            when 'active'   then scope.active
            when 'inactive' then scope.inactive
            else scope
            end
    scope = scope.order(:created_at)

    case format_type
    when 'csv'
      send_data generate_distributors_csv(scope), filename: "ambassadors_#{Date.current}.csv", type: 'text/csv'
    when 'excel'
      send_data generate_distributors_excel(scope),
                filename: "ambassadors_#{Date.current}.xlsx",
                type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    else
      redirect_to admin_distributors_path, alert: 'Invalid download format.'
    end
  end

  private

  def generate_distributors_csv(records)
    require 'csv'
    CSV.generate(headers: true) do |csv|
      csv << %w[ID FirstName MiddleName LastName Mobile Email CompanyName PAN GST
                Address City State BirthDate Gender BankName AccountNo IFSC
                AccountHolderName AccountType UPIID AffiliateCount Status CreatedAt]
      records.find_each do |d|
        csv << [d.id, d.first_name, d.middle_name, d.last_name, d.mobile, d.email,
                d.company_name, d.pan_no, d.gst_no, d.address, d.city, d.state,
                d.birth_date, d.gender&.humanize, d.bank_name, d.account_no, d.ifsc_code,
                d.account_holder_name, d.account_type, d.upi_id, d.affiliate_count,
                d.deactivated? ? 'Deactivated' : (d.active? ? 'Active' : 'Inactive'),
                d.created_at.strftime('%Y-%m-%d %H:%M:%S')]
      end
    end
  end

  def generate_distributors_excel(records)
    require 'caxlsx'
    package = Axlsx::Package.new
    wb = package.workbook
    hdr = wb.styles.add_style(bg_color: '1565C0', fg_color: 'FFFFFF', b: true,
                               alignment: { horizontal: :center })
    row = wb.styles.add_style(alignment: { horizontal: :left })
    wb.add_worksheet(name: 'Ambassadors') do |sheet|
      sheet.add_row %w[ID FirstName MiddleName LastName Mobile Email CompanyName PAN GST
                       Address City State BirthDate Gender BankName AccountNo IFSC
                       AccountHolderName AccountType UPIID AffiliateCount Status CreatedAt], style: hdr
      records.find_each do |d|
        sheet.add_row [d.id, d.first_name, d.middle_name, d.last_name, d.mobile, d.email,
                       d.company_name, d.pan_no, d.gst_no, d.address, d.city, d.state,
                       d.birth_date&.to_s, d.gender&.humanize, d.bank_name, d.account_no,
                       d.ifsc_code, d.account_holder_name, d.account_type, d.upi_id,
                       d.affiliate_count,
                       d.deactivated? ? 'Deactivated' : (d.active? ? 'Active' : 'Inactive'),
                       d.created_at.strftime('%Y-%m-%d %H:%M:%S')], style: row
      end
    end
    package.to_stream.read
  end

  def create_ambassador_user_account(distributor)
    return unless distributor&.email.present?

    # Check if user already exists
    existing_user = User.find_by(email: distributor.email)
    return if existing_user

    # Get ambassador roles
    ambassador_user_role = UserRole.find_by(name: 'Ambassador')
    ambassador_role = Role.find_by(name: 'ambassador') || Role.find_by(name: 'Ambassador')

    # Determine password based on form selection
    password = determine_ambassador_password

    begin
      # Create user with determined password
      user = User.create!(
        first_name: distributor.first_name || 'Ambassador',
        last_name: distributor.last_name || 'User',
        email: distributor.email,
        password: password,
        password_confirmation: password,
        mobile: distributor.mobile,
        user_type: 'ambassador',
        role: ambassador_role,
        user_role: ambassador_user_role,
        status: true,
        original_password: password
      )

      Rails.logger.info "✅ Ambassador user account created: #{user.email} with password: #{password}"
    rescue => e
      Rails.logger.error "❌ Failed to create ambassador user: #{e.message}"
    end
  end

  def set_distributor
    @distributor = Distributor.includes(:distributor_documents).find(params[:id])
  end

  def determine_ambassador_password
    password_option = params[:password_option] || 'auto_generate'

    if password_option == 'manual' && params[:distributor][:password].present?
      params[:distributor][:password]
    else
      'Ganesha@123'
    end
  end

  def distributor_params
    params.require(:distributor).permit(
      :first_name, :middle_name, :last_name, :mobile, :email, :role_id,
      :state_id, :city_id, :state, :city, :birth_date, :gender, :pan_no, :gst_no,
      :company_name, :address, :bank_name, :account_no, :ifsc_code,
      :account_holder_name, :account_type, :upi_id, :status, :upload_main_document, :investor_id,
      :password, :password_confirmation, :profile_image,
      assigned_affiliate_ids: [],
      distributor_documents_attributes: [:id, :document_type, :document_file, :_destroy],
      uploaded_documents_attributes: [:id, :title, :description, :document_type, :file, :uploaded_by, :_destroy]
    )
  end

  def handle_affiliate_assignments(distributor, assigned_affiliate_ids)
    distributor.distributor_assignments.destroy_all

    return if assigned_affiliate_ids.nil? || assigned_affiliate_ids.empty?

    ids = Array(assigned_affiliate_ids).reject(&:blank?).map(&:to_i)
    return if ids.empty?

    # Batch: load all sub_agents in one query, remove stale cross-distributor assignments in one query
    sub_agents = SubAgent.where(id: ids).index_by(&:id)
    DistributorAssignment.where(sub_agent_id: ids).destroy_all

    ids.each do |sub_agent_id|
      sub_agent = sub_agents[sub_agent_id]
      if sub_agent
        distributor.distributor_assignments.create!(sub_agent: sub_agent, assigned_at: Time.current)
      else
        Rails.logger.warn "SubAgent with ID #{sub_agent_id} not found"
      end
    end
  end

  def batch_calculate_affiliate_stats(affiliates)
    return {} if affiliates.empty?

    affiliate_ids = affiliates.map(&:id)

    # 3 group queries (one per type) instead of N*3 individual queries
    health_rows = HealthInsurance.where(sub_agent_id: affiliate_ids)
      .group(:sub_agent_id)
      .pluck(:sub_agent_id, Arel.sql('COUNT(*)'), Arel.sql('COALESCE(SUM(total_premium),0)'), Arel.sql('ARRAY_AGG(id)'), Arel.sql('ARRAY_AGG(customer_id)'))
    life_rows = LifeInsurance.where(sub_agent_id: affiliate_ids)
      .group(:sub_agent_id)
      .pluck(:sub_agent_id, Arel.sql('COUNT(*)'), Arel.sql('COALESCE(SUM(total_premium),0)'), Arel.sql('ARRAY_AGG(id)'), Arel.sql('ARRAY_AGG(customer_id)'))
    motor_rows = MotorInsurance.where(sub_agent_id: affiliate_ids)
      .group(:sub_agent_id)
      .pluck(:sub_agent_id, Arel.sql('COUNT(*)'), Arel.sql('COALESCE(SUM(total_premium),0)'), Arel.sql('ARRAY_AGG(id)'), Arel.sql('ARRAY_AGG(customer_id)'))

    health_by = health_rows.index_by { |r| r[0] }
    life_by   = life_rows.index_by   { |r| r[0] }
    motor_by  = motor_rows.index_by  { |r| r[0] }

    # Collect all policy IDs for batch commission lookup (3 queries instead of N*3)
    all_health_ids = health_rows.flat_map { |r| r[3] }.compact
    all_life_ids   = life_rows.flat_map   { |r| r[3] }.compact
    all_motor_ids  = motor_rows.flat_map  { |r| r[3] }.compact

    h_comm = CommissionPayout.where(policy_type: 'health', policy_id: all_health_ids, payout_to: 'ambassador')
                             .group(:policy_id).sum(:payout_amount)
    l_comm = CommissionPayout.where(policy_type: 'life',   policy_id: all_life_ids,   payout_to: 'ambassador')
                             .group(:policy_id).sum(:payout_amount)
    m_comm = CommissionPayout.where(policy_type: 'motor',  policy_id: all_motor_ids,  payout_to: 'ambassador')
                             .group(:policy_id).sum(:payout_amount)

    affiliate_ids.index_with do |aid|
      h = health_by[aid]; l = life_by[aid]; m = motor_by[aid]

      h_count = h ? h[1].to_i : 0; h_premium = h ? h[2].to_f : 0.0
      l_count = l ? l[1].to_i : 0; l_premium = l ? l[2].to_f : 0.0
      m_count = m ? m[1].to_i : 0; m_premium = m ? m[2].to_f : 0.0

      h_ids = h ? h[3].compact : []; l_ids = l ? l[3].compact : []; m_ids = m ? m[3].compact : []
      total_commission = h_ids.sum { |id| h_comm[id].to_f } +
                         l_ids.sum { |id| l_comm[id].to_f } +
                         m_ids.sum { |id| m_comm[id].to_f }

      cust_ids = ((h ? h[4].compact : []) + (l ? l[4].compact : []) + (m ? m[4].compact : [])).uniq

      {
        total_policies: h_count + l_count + m_count,
        total_premium: h_premium + l_premium + m_premium,
        total_commission: total_commission.to_f,
        health_policies: h_count,
        life_policies: l_count,
        motor_policies: m_count,
        other_policies: 0,
        recent_policies: [],
        customers_count: cust_ids.count,
        joined_date: affiliates.find { |a| a.id == aid }&.created_at
      }
    end
  end

  def calculate_affiliate_stats(affiliate)
    batch_calculate_affiliate_stats([affiliate])[affiliate.id] || {}
  end

  def calculate_distributor_stats
    total_policies = 0
    total_premium = 0.0
    total_commission = 0.0
    total_customers = 0

    @assigned_affiliates.each do |affiliate|
      stats = @affiliate_stats[affiliate.id]
      total_policies += stats[:total_policies]
      total_premium += stats[:total_premium]
      total_commission += stats[:total_commission]
      total_customers += stats[:customers_count]
    end

    {
      total_affiliates: @assigned_affiliates.count,
      active_affiliates: @assigned_affiliates.active.count,
      total_policies: total_policies,
      total_premium: total_premium,
      total_commission: total_commission,
      total_customers: total_customers,
      avg_policies_per_affiliate: @assigned_affiliates.count > 0 ? (total_policies.to_f / @assigned_affiliates.count).round(2) : 0
    }
  end

  def get_recent_policies_for_affiliate(affiliate)
    policies = []

    # Get recent health policies
    HealthInsurance.where(sub_agent_id: affiliate.id)
                   .includes(:customer)
                   .order(created_at: :desc)
                   .limit(3)
                   .each do |policy|
      policies << {
        id: policy.id,
        type: 'Health',
        policy_number: policy.policy_number,
        customer: policy.customer&.display_name || 'Unknown',
        premium: policy.total_premium,
        created_at: policy.created_at
      }
    end

    # Get recent life policies
    LifeInsurance.where(sub_agent_id: affiliate.id)
                 .includes(:customer)
                 .order(created_at: :desc)
                 .limit(3)
                 .each do |policy|
      policies << {
        id: policy.id,
        type: 'Life',
        policy_number: policy.policy_number,
        customer: policy.customer&.display_name || 'Unknown',
        premium: policy.total_premium,
        created_at: policy.created_at
      }
    end

    # Get recent motor policies
    MotorInsurance.where(sub_agent_id: affiliate.id)
                  .includes(:customer)
                  .order(created_at: :desc)
                  .limit(2)
                  .each do |policy|
      policies << {
        id: policy.id,
        type: 'Motor',
        policy_number: policy.policy_number,
        customer: policy.customer&.display_name || 'Unknown',
        premium: policy.total_premium,
        created_at: policy.created_at
      }
    end

    # Sort by creation date and return top 5
    policies.sort_by { |p| p[:created_at] }.reverse.first(5)
  end

  def calculate_single_distributor_payouts(distributor_id)
    payouts = CommissionPayout.where(payout_to: 'ambassador').to_a
    return { leads: [], total_amount: 0.0, paid_amount: 0.0, pending_amount: 0.0, lead_count: 0 } if payouts.empty?

    # Preload all policies grouped by type (avoids 1 query per payout)
    ids_by_type = payouts.group_by(&:policy_type).transform_values { |ps| ps.map(&:policy_id).compact.uniq }
    policy_map = {}
    { 'health' => HealthInsurance, 'life' => LifeInsurance, 'motor' => MotorInsurance }.each do |pt, klass|
      next if ids_by_type[pt].blank?
      policy_map[pt] = klass.where(id: ids_by_type[pt]).index_by(&:id)
    end
    begin
      if ids_by_type['other'].present? && defined?(OtherInsurance)
        policy_map['other'] = OtherInsurance.where(id: ids_by_type['other']).index_by(&:id)
      end
    rescue; end

    # Preload all leads by lead_id in one query
    all_lead_ids = payouts.map(&:lead_id).compact.uniq
    leads_by_lead_id = all_lead_ids.any? ? Lead.where(lead_id: all_lead_ids).index_by(&:lead_id) : {}

    leads = []; total_amount = 0.0; paid_amount = 0.0; pending_amount = 0.0

    payouts.each do |payout|
      policy = policy_map.dig(payout.policy_type, payout.policy_id)
      next unless policy
      next unless policy.respond_to?(:main_agent_commission_received) && policy.main_agent_commission_received
      next unless policy.respond_to?(:distributor_id) && policy.distributor_id == distributor_id

      lead = payout.lead_id.present? ? leads_by_lead_id[payout.lead_id] : nil
      lead ||= (policy.respond_to?(:lead_id) && policy.lead_id.present?) ? leads_by_lead_id[policy.lead_id] : nil
      lead ||= OpenStruct.new(
        id: "virtual_#{policy.id}",
        lead_id: policy.try(:lead_id) || "POLICY-#{policy.id}",
        created_at: policy.created_at
      )

      amount = payout.payout_amount.to_f
      paid = payout.status == 'paid'
      total_amount += amount
      paid ? paid_amount += amount : pending_amount += amount
      leads << { lead: lead, commission: amount, paid: paid }
    end

    { leads: leads, total_amount: total_amount, paid_amount: paid_amount, pending_amount: pending_amount, lead_count: leads.count }
  end

  def calculate_distributor_stats_basic
    total_policies = 0
    total_premium = 0.0
    total_customers = 0

    @assigned_affiliates.each do |affiliate|
      stats = @affiliate_stats[affiliate.id]
      total_policies += stats[:total_policies]
      total_premium += stats[:total_premium]
      total_customers += stats[:customers_count]
    end

    {
      total_affiliates: @assigned_affiliates.count,
      active_affiliates: @assigned_affiliates.active.count,
      total_policies: total_policies,
      total_premium: total_premium,
      total_customers: total_customers,
      avg_policies_per_affiliate: @assigned_affiliates.count > 0 ? (total_policies.to_f / @assigned_affiliates.count).round(2) : 0
    }
  end

  def get_policy_from_commission_payout(commission_payout)
    case commission_payout.policy_type
    when 'health'
      HealthInsurance.find_by(id: commission_payout.policy_id)
    when 'life'
      LifeInsurance.find_by(id: commission_payout.policy_id)
    when 'motor'
      MotorInsurance.find_by(id: commission_payout.policy_id)
    when 'other'
      OtherInsurance.find_by(id: commission_payout.policy_id) if defined?(OtherInsurance)
    end
  end

  def build_distributor_ledger(distributor)
    health_ids = HealthInsurance.where(distributor_id: distributor.id).pluck(:id)
    life_ids   = LifeInsurance.where(distributor_id: distributor.id).pluck(:id)
    motor_ids  = MotorInsurance.where(distributor_id: distributor.id).pluck(:id)

    return [] if health_ids.empty? && life_ids.empty? && motor_ids.empty?

    scope = CommissionPayout.none
    scope = scope.or(CommissionPayout.where(payout_to: 'ambassador', policy_type: 'health', policy_id: health_ids)) if health_ids.any?
    scope = scope.or(CommissionPayout.where(payout_to: 'ambassador', policy_type: 'life',   policy_id: life_ids))   if life_ids.any?
    scope = scope.or(CommissionPayout.where(payout_to: 'ambassador', policy_type: 'motor',  policy_id: motor_ids))  if motor_ids.any?
    payouts = scope.order(:created_at)

    all_health = HealthInsurance.includes(:customer).where(id: health_ids).index_by(&:id)
    all_life   = LifeInsurance.includes(:customer).where(id: life_ids).index_by(&:id)
    all_motor  = MotorInsurance.includes(:customer).where(id: motor_ids).index_by(&:id)

    raw_ledger = []
    payouts.each do |payout|
      policy = case payout.policy_type
               when 'health' then all_health[payout.policy_id]
               when 'life'   then all_life[payout.policy_id]
               when 'motor'  then all_motor[payout.policy_id]
               end
      next unless policy

      amount = payout.payout_amount.to_f
      next if amount <= 0

      customer_name = policy.customer&.display_name || 'Unknown'

      raw_ledger << {
        date: payout.created_at&.to_date || Date.current,
        description: 'Commission Earned',
        policy_number: policy.policy_number,
        policy_type: payout.policy_type.humanize,
        policy_type_raw: payout.policy_type,
        policy_id: policy.id,
        customer_name: customer_name,
        credit: amount,
        debit: 0.0
      }

      if payout.status == 'paid'
        raw_ledger << {
          date: payout.payout_date || payout.updated_at&.to_date || Date.current,
          description: 'Payout Received',
          policy_number: policy.policy_number,
          policy_type: payout.policy_type.humanize,
          policy_type_raw: payout.policy_type,
          policy_id: policy.id,
          customer_name: customer_name,
          credit: 0.0,
          debit: amount
        }
      end
    end

    raw_ledger.sort_by! { |e| [e[:date], e[:credit] > 0 ? 0 : 1] }
    balance = 0.0
    raw_ledger.map do |entry|
      balance = (balance + entry[:credit] - entry[:debit]).round(2)
      entry.merge(balance: balance)
    end
  end

  def handle_profile_image_upload(distributor, profile_image_file)
    return unless profile_image_file.present?

    begin
      Rails.logger.info "📸 Processing profile image upload for distributor #{distributor.id}"

      # Delete existing profile image document if exists
      existing_profile_doc = distributor.distributor_documents.where(document_type: 'Profile Image').first
      if existing_profile_doc
        Rails.logger.info "🗑️ Removing existing profile image document"
        existing_profile_doc.destroy
      end

      # Create new profile image document
      profile_doc = distributor.distributor_documents.build(
        document_type: 'Profile Image',
        document_file: profile_image_file
      )

      if profile_doc.save
        Rails.logger.info "✅ Profile image uploaded to R2 successfully"
      else
        Rails.logger.error "❌ Profile image upload failed: #{profile_doc.errors.full_messages}"
      end

    rescue => e
      Rails.logger.error "❌ Profile image upload error: #{e.message}"
    end
  end
end
