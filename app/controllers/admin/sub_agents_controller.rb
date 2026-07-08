class Admin::SubAgentsController < Admin::ApplicationController
  include ConfigurablePagination
  before_action :set_sub_agent, only: [:show, :edit, :update, :destroy, :documents, :create_missing_payouts]

  # GET /admin/sub_agents
  def index
    # Eager load associations to prevent N+1 queries
    @sub_agents = SubAgent.includes(:assigned_distributor, :profile_image_attachment)

    # Search functionality
    if params[:search].present?
      @sub_agents = @sub_agents.search_by_name_mobile_email(params[:search])
    end

    # Filter by status
    case params[:status]
    when 'active'
      @sub_agents = @sub_agents.active
    when 'inactive'
      @sub_agents = @sub_agents.inactive
    end

    # Get total count before pagination for display purposes
    @total_filtered_count = @sub_agents.count

    # Order and paginate using configurable pagination
    @sub_agents = paginate_records(@sub_agents.order(created_at: :desc))

    # All four stats in one query instead of 3 count queries + Ruby iteration
    stats = ActiveRecord::Base.connection.execute(<<~SQL).first
      SELECT
        COUNT(*)                                                                                 AS total,
        COUNT(*) FILTER (WHERE status = 0)                                                       AS active_count,
        COUNT(*) FILTER (WHERE status = 1)                                                       AS inactive_count,
        COUNT(*) FILTER (WHERE id NOT IN (SELECT sub_agent_id FROM distributor_assignments WHERE sub_agent_id IS NOT NULL)) AS unassigned_count
      FROM sub_agents
    SQL
    @total_sub_agents      = stats['total'].to_i
    @active_sub_agents     = stats['active_count'].to_i
    @inactive_sub_agents   = stats['inactive_count'].to_i
    @unassigned_sub_agents = stats['unassigned_count'].to_i

    # Preload policy counts for all sub_agents to avoid N+1 queries
    sub_agent_ids = @sub_agents.map(&:id)

    # Get policy counts in single queries
    @health_policy_counts = HealthInsurance.where(sub_agent_id: sub_agent_ids)
                                          .group(:sub_agent_id)
                                          .count
    @life_policy_counts = LifeInsurance.where(sub_agent_id: sub_agent_ids)
                                       .group(:sub_agent_id)
                                       .count
    @motor_policy_counts = MotorInsurance.where(sub_agent_id: sub_agent_ids)
                                         .group(:sub_agent_id)
                                         .count
  end

  # GET /admin/sub_agents/1
  def show
    @documents = @sub_agent.sub_agent_documents.order(:created_at)
    @assigned_distributor = @sub_agent.assigned_distributor
    @distributor_assignment = @sub_agent.distributor_assignment

    # Get policies handled by this sub agent
    @health_policies = HealthInsurance.where(sub_agent_id: @sub_agent.id).includes(:customer).order(:created_at => :desc)
    @life_policies = LifeInsurance.where(sub_agent_id: @sub_agent.id).includes(:customer).order(:created_at => :desc)
    @motor_policies = MotorInsurance.where(sub_agent_id: @sub_agent.id).includes(:customer).order(:created_at => :desc)

    # Combine all policies for summary
    @all_policies = []

    @health_policies.each do |policy|
      @all_policies << {
        type: 'Health Insurance',
        policy: policy,
        policy_number: policy.policy_number,
        customer_name: policy.customer.display_name,
        company_name: policy.insurance_company_name,
        premium: policy.total_premium,
        start_date: policy.policy_start_date,
        end_date: policy.policy_end_date,
        status: policy.active? ? 'Active' : 'Expired',
        created_at: policy.created_at
      }
    end

    @life_policies.each do |policy|
      @all_policies << {
        type: 'Life Insurance',
        policy: policy,
        policy_number: policy.policy_number,
        customer_name: policy.customer.display_name,
        company_name: policy.insurance_company_name,
        premium: policy.total_premium,
        start_date: policy.policy_start_date,
        end_date: policy.policy_end_date,
        status: policy.active? ? 'Active' : 'Expired',
        created_at: policy.created_at
      }
    end

    @motor_policies.each do |policy|
      @all_policies << {
        type: 'Motor Insurance',
        policy: policy,
        policy_number: policy.policy_number,
        customer_name: policy.customer.display_name,
        company_name: policy.insurance_company_name,
        premium: policy.total_premium,
        start_date: policy.policy_start_date,
        end_date: policy.policy_end_date,
        status: policy.active? ? 'Active' : 'Expired',
        created_at: policy.created_at
      }
    end

    # Sort all policies by creation date (newest first)
    @all_policies.sort_by! { |p| p[:created_at] }.reverse!

    # Get commission payouts for this sub agent (check both 'sub_agent' and 'affiliate')
    @commission_payouts = CommissionPayout.where(payout_to: ['sub_agent', 'affiliate'])
                                         .joins("LEFT JOIN health_insurances ON commission_payouts.policy_type = 'health' AND commission_payouts.policy_id = health_insurances.id
                                                 LEFT JOIN life_insurances ON commission_payouts.policy_type = 'life' AND commission_payouts.policy_id = life_insurances.id
                                                 LEFT JOIN motor_insurances ON commission_payouts.policy_type = 'motor' AND commission_payouts.policy_id = motor_insurances.id")
                                         .where(
                                           "(commission_payouts.policy_type = 'health' AND health_insurances.sub_agent_id = ?) OR
                                            (commission_payouts.policy_type = 'life' AND life_insurances.sub_agent_id = ?) OR
                                            (commission_payouts.policy_type = 'motor' AND motor_insurances.sub_agent_id = ?)",
                                           @sub_agent.id, @sub_agent.id, @sub_agent.id
                                         ).order(:payout_date => :desc)

    # Preload policies once to avoid N+1 when computing TDS breakdowns
    payout_records = @commission_payouts.to_a
    preloaded_policies = {}
    payout_records.group_by(&:policy_type).each do |ptype, ps|
      klass = { 'health' => HealthInsurance, 'life' => LifeInsurance,
                'motor' => MotorInsurance,   'other' => OtherInsurance }[ptype]
      next unless klass
      ids = ps.map(&:policy_id).uniq.compact
      preloaded_policies[ptype] = klass.where(id: ids).index_by(&:id)
    end

    customer_ids = preloaded_policies.values
                    .flat_map { |h| h.values.map { |p| p.try(:customer_id) } }
                    .uniq.compact
    customers_by_id = Customer.where(id: customer_ids).index_by(&:id)

    @commission_details = payout_records.map do |payout|
      pol      = preloaded_policies.dig(payout.policy_type, payout.policy_id)
      customer = pol ? customers_by_id[pol.try(:customer_id)] : nil
      gross    = pol&.try(:sub_agent_commission_amount).to_f
      tds      = pol&.try(:sub_agent_tds_amount).to_f
      net      = pol&.try(:sub_agent_after_tds_value).to_f
      net      = (gross - tds).round(2) if net.zero? && gross > 0
      net      = payout.payout_amount.to_f if net.zero?
      gross    = net + tds if gross.zero?
      {
        payout: payout,
        policy_number: pol&.policy_number || 'N/A',
        customer_name: customer&.display_name || 'Unknown',
        gross: gross,
        tds: tds,
        net: net
      }
    end

    @total_gross_commission  = @commission_details.sum { |d| d[:gross] }
    @total_tds_amount        = @commission_details.sum { |d| d[:tds] }
    @total_net_commission    = @commission_details.sum { |d| d[:net] }
    @total_commission_earned = @total_net_commission
    @paid_commission         = @commission_details.select { |d| d[:payout].status == 'paid' }.sum { |d| d[:net] }
    @pending_commission      = @commission_details.select { |d| d[:payout].status == 'pending' }.sum { |d| d[:net] }
    @processing_commission   = @commission_details.select { |d| d[:payout].status == 'processing' }.sum { |d| d[:net] }

    # Policy summary calculations
    @total_policies = @all_policies.count
    @active_policies = @all_policies.count { |p| p[:status] == 'Active' }
    @expired_policies = @all_policies.count { |p| p[:status] == 'Expired' }
    @total_premium_handled = @all_policies.sum { |p| p[:premium] || 0 }
    @unique_clients = Customer.where(sub_agent_id: @sub_agent.id).count
    @client_details = Customer.where(sub_agent_id: @sub_agent.id)
                              .select(:id, :first_name, :middle_name, :last_name, :company_name,
                                      :customer_type, :email, :mobile, :gender, :birth_date,
                                      :state, :city, :status, :policies_count, :created_at)
                              .order(:first_name)

    # Build commission ledger
    raw_ledger = []
    @commission_details.each do |detail|
      payout = detail[:payout]
      net_amount = detail[:net].to_f
      next if net_amount <= 0

      raw_ledger << {
        date: payout.created_at&.to_date || Date.current,
        description: 'Commission Earned',
        policy_number: detail[:policy_number],
        policy_type: payout.policy_type&.humanize,
        policy_type_raw: payout.policy_type,
        policy_id: payout.policy_id,
        customer_name: detail[:customer_name],
        credit: net_amount,
        debit: 0.0
      }

      if payout.status == 'paid'
        raw_ledger << {
          date: payout.payout_date || payout.updated_at&.to_date || Date.current,
          description: 'Payout Received',
          policy_number: detail[:policy_number],
          policy_type: payout.policy_type&.humanize,
          policy_type_raw: payout.policy_type,
          policy_id: payout.policy_id,
          customer_name: detail[:customer_name],
          credit: 0.0,
          debit: net_amount
        }
      end
    end

    raw_ledger.sort_by! { |e| [e[:date], e[:credit] > 0 ? 0 : 1] }
    balance = 0.0
    @ledger_entries = raw_ledger.map do |entry|
      balance = (balance + entry[:credit] - entry[:debit]).round(2)
      entry.merge(balance: balance)
    end
    @ledger_closing_balance = balance
  end

  # POST /admin/sub_agents/1/create_missing_payouts
  def create_missing_payouts
    created = 0
    skipped = 0
    errors   = []

    policy_types = [
      [HealthInsurance, 'health'],
      [LifeInsurance,   'life'],
      [MotorInsurance,  'motor']
    ]

    policy_types.each do |klass, ptype|
      policies    = klass.where(sub_agent_id: @sub_agent.id)
      policy_ids  = policies.pluck(:id)
      existing_ids = CommissionPayout
        .where(policy_type: ptype, policy_id: policy_ids, payout_to: ['affiliate', 'sub_agent'])
        .pluck(:policy_id).to_set

      policies.each do |policy|
        if existing_ids.include?(policy.id)
          skipped += 1
          next
        end

        begin
          amount = policy.try(:sub_agent_after_tds_value).presence ||
                   policy.try(:sub_agent_commission_amount).presence ||
                   (policy.net_premium.to_f * 0.02)
          amount = amount.to_f

          if amount <= 0
            skipped += 1
            next
          end

          CommissionPayout.create!(
            policy_type:             ptype,
            policy_id:               policy.id,
            lead_id:                 policy.try(:lead_id),
            payout_to:               'affiliate',
            payout_amount:           amount.round(2),
            payout_date:             Date.current,
            status:                  'pending',
            payment_mode:            'bank_transfer',
            reference_number:        "AFF_MANUAL_#{policy.id}_#{Time.current.to_i}",
            distribution_percentage: policy.try(:sub_agent_commission_percentage).to_f,
            notes:                   "Affiliate commission for #{ptype} policy ##{policy.policy_number}. Created manually for missing payout.",
            processed_by:            'admin_manual'
          )
          created += 1
        rescue => e
          errors << "#{ptype} policy ##{policy.try(:policy_number)}: #{e.message}"
          Rails.logger.error "create_missing_payouts error: #{e.message}"
        end
      end
    end

    if errors.any?
      redirect_to admin_sub_agent_path(@sub_agent),
        alert: "Created #{created} payout(s). #{errors.count} error(s): #{errors.join('; ')}"
    else
      redirect_to admin_sub_agent_path(@sub_agent),
        notice: "Done — #{created} payout(s) created, #{skipped} already existed."
    end
  end

  # GET /admin/sub_agents/1/documents
  def documents
    @documents = @sub_agent.sub_agent_documents.order(:created_at)
    @uploaded_documents = @sub_agent.respond_to?(:uploaded_documents) ? @sub_agent.uploaded_documents.order(:created_at) : []
  end

  # GET /admin/sub_agents/new
  def new
    @sub_agent = SubAgent.new
    @sub_agent.sub_agent_documents.build
    @available_distributors = Distributor.active.order(:first_name, :last_name)
  end

  # GET /admin/sub_agents/1/edit
  def edit
    # Load documents for display
    @documents = @sub_agent.sub_agent_documents.order(:created_at)

    # Only build a new document placeholder if there are no documents (this won't affect display)
    @sub_agent.sub_agent_documents.build if @sub_agent.sub_agent_documents.empty?

    @assigned_distributor = @sub_agent.assigned_distributor
    @distributor_assignment = @sub_agent.distributor_assignment
    @available_distributors = Distributor.active.order(:first_name, :last_name)

    # Get basic policy and commission summary for quick reference
    @total_policies = HealthInsurance.where(sub_agent_id: @sub_agent.id).count +
                     LifeInsurance.where(sub_agent_id: @sub_agent.id).count +
                     MotorInsurance.where(sub_agent_id: @sub_agent.id).count

    @total_commission = CommissionPayout.where(payout_to: ['sub_agent', 'affiliate'])
                                       .joins("LEFT JOIN health_insurances ON commission_payouts.policy_type = 'health' AND commission_payouts.policy_id = health_insurances.id
                                               LEFT JOIN life_insurances ON commission_payouts.policy_type = 'life' AND commission_payouts.policy_id = life_insurances.id
                                               LEFT JOIN motor_insurances ON commission_payouts.policy_type = 'motor' AND commission_payouts.policy_id = motor_insurances.id")
                                       .where(
                                         "(commission_payouts.policy_type = 'health' AND health_insurances.sub_agent_id = ?) OR
                                          (commission_payouts.policy_type = 'life' AND life_insurances.sub_agent_id = ?) OR
                                          (commission_payouts.policy_type = 'motor' AND motor_insurances.sub_agent_id = ?)",
                                         @sub_agent.id, @sub_agent.id, @sub_agent.id
                                       ).sum(:payout_amount)
  end

  # POST /admin/sub_agents
  def create
    Rails.logger.info "=== SUB AGENT CREATE PARAMS ==="
    Rails.logger.info "Documents attributes: #{params[:sub_agent][:sub_agent_documents_attributes].inspect}"

    @sub_agent = SubAgent.new(sub_agent_params)

    # Force role to be sub_agent regardless of form input
    @sub_agent.role_id = Role.find_or_create_by(name: 'sub_agent') { |r| r.status = true }.id

    # Auto-generate password if not provided
    if @sub_agent.password.blank?
      generated_password = generate_affiliate_password
      @sub_agent.password = generated_password
      @sub_agent.password_confirmation = generated_password
    end

    if @sub_agent.save
      # Create User account for the sub agent
      create_user_account_for_sub_agent(@sub_agent)
      handle_distributor_assignment(@sub_agent, params[:assigned_distributor_id])
      Rails.logger.info "Documents after create: #{@sub_agent.sub_agent_documents.count}"
      redirect_to admin_sub_agents_path, notice: 'Affiliate was successfully created.'
    else
      Rails.logger.error "Create errors: #{@sub_agent.errors.full_messages}"

      # If mobile or email is already taken, redirect to the existing affiliate
      existing_by_mobile = SubAgent.find_by(mobile: @sub_agent.mobile) if @sub_agent.mobile.present?
      existing_by_email  = SubAgent.find_by(email: @sub_agent.email)   if @sub_agent.email.present?
      existing = existing_by_mobile || existing_by_email

      if existing
        redirect_to edit_admin_sub_agent_path(existing),
                    alert: "An affiliate with this mobile/email already exists. You can update the details here."
        return
      end

      @sub_agent.sub_agent_documents.build if @sub_agent.sub_agent_documents.empty?
      @available_distributors = Distributor.active.order(:first_name, :last_name)
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /admin/sub_agents/1
  def update
    Rails.logger.info "=== SUB AGENT UPDATE PARAMS ==="
    Rails.logger.info "Documents attributes: #{params[:sub_agent][:sub_agent_documents_attributes].inspect}"

    # Force role to be sub_agent regardless of form input
    params[:sub_agent][:role_id] = Role.find_or_create_by(name: 'sub_agent') { |r| r.status = true }.id

    if @sub_agent.update(sub_agent_params)
      handle_distributor_assignment(@sub_agent, params[:assigned_distributor_id])
      Rails.logger.info "Documents after update: #{@sub_agent.sub_agent_documents.count}"
      redirect_to admin_sub_agents_path, notice: 'Affiliate was successfully updated.'
    else
      Rails.logger.error "Update errors: #{@sub_agent.errors.full_messages}"
      @sub_agent.sub_agent_documents.build if @sub_agent.sub_agent_documents.empty?
      @assigned_distributor = @sub_agent.assigned_distributor
      @distributor_assignment = @sub_agent.distributor_assignment
      @available_distributors = Distributor.active.order(:first_name, :last_name)
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/sub_agents/1
  def destroy
    # Check for relationships that would prevent deletion
    has_customers = @sub_agent.customers.exists?
    has_documents = @sub_agent.sub_agent_documents.exists?
    has_distributor_assignment = @sub_agent.distributor_assignment.present?

    # Check for insurance policies linked to this sub_agent
    has_health_policies = HealthInsurance.where(sub_agent_id: @sub_agent.id).exists? rescue false
    has_life_policies = LifeInsurance.where(sub_agent_id: @sub_agent.id).exists? rescue false
    has_motor_policies = MotorInsurance.where(sub_agent_id: @sub_agent.id).exists? rescue false
    has_other_policies = defined?(OtherInsurance) && OtherInsurance.where(sub_agent_id: @sub_agent.id).exists? rescue false

    # Check for leads linked to this affiliate
    has_leads = Lead.where(affiliate_id: @sub_agent.id).exists? rescue false

    # Check for corresponding User account
    has_user_account = User.where(email: @sub_agent.email).exists? rescue false

    if has_customers || has_health_policies || has_life_policies || has_motor_policies || has_other_policies || has_leads
      error_messages = []

      if has_customers
        customer_count = @sub_agent.customers.count
        error_messages << "#{customer_count} customer(s)"
      end

      policy_count = 0
      policy_count += HealthInsurance.where(sub_agent_id: @sub_agent.id).count rescue 0
      policy_count += LifeInsurance.where(sub_agent_id: @sub_agent.id).count rescue 0
      policy_count += MotorInsurance.where(sub_agent_id: @sub_agent.id).count rescue 0
      policy_count += OtherInsurance.where(sub_agent_id: @sub_agent.id).count rescue 0 if defined?(OtherInsurance)

      if policy_count > 0
        error_messages << "#{policy_count} insurance policy(ies)"
      end

      if has_leads
        lead_count = Lead.where(affiliate_id: @sub_agent.id).count rescue 0
        error_messages << "#{lead_count} lead(s)" if lead_count > 0
      end

      message = "Cannot delete affiliate with #{error_messages.join(', ')}. Please reassign or remove these records first."
      redirect_to admin_sub_agents_path, alert: message
    else
      begin
        # Delete associated records that can be safely removed
        if has_documents
          @sub_agent.sub_agent_documents.destroy_all
        end

        if has_distributor_assignment
          @sub_agent.distributor_assignment.destroy
        end

        # Delete corresponding User account if it exists
        if has_user_account
          user = User.find_by(email: @sub_agent.email)
          user&.destroy
        end

        # Now destroy the sub_agent
        @sub_agent.destroy!
        redirect_to admin_sub_agents_path, notice: 'Affiliate was successfully deleted.'
      rescue => e
        redirect_to admin_sub_agents_path,
                    alert: "Failed to delete affiliate: #{e.message}"
      end
    end
  end

  # PATCH /admin/sub_agents/1/toggle_status
  def toggle_status
    @sub_agent = SubAgent.find(params[:id])
    new_status = @sub_agent.active? ? :inactive : :active

    if @sub_agent.update(status: new_status)
      redirect_to admin_sub_agents_path, notice: "Sub Agent status updated to #{new_status}."
    else
      redirect_to admin_sub_agents_path, alert: 'Failed to update status.'
    end
  end

  # PATCH /admin/sub_agents/1/deactivate
  def deactivate
    @sub_agent = SubAgent.find(params[:id])
    if @sub_agent.deactivate!
      redirect_to admin_sub_agents_path, notice: 'Affiliate was successfully deactivated.'
    else
      redirect_to admin_sub_agents_path, alert: 'Failed to deactivate affiliate.'
    end
  end

  # PATCH /admin/sub_agents/1/activate
  def activate
    @sub_agent = SubAgent.find(params[:id])
    if @sub_agent.activate!
      redirect_to admin_sub_agents_path, notice: 'Affiliate was successfully activated.'
    else
      redirect_to admin_sub_agents_path, alert: 'Failed to activate affiliate.'
    end
  end

  # GET /admin/sub_agents/1/distributor
  def distributor
    @sub_agent = SubAgent.find(params[:id])

    # Check for direct distributor relationship first, then fall back to assignment
    distributor_id = @sub_agent.distributor_id || @sub_agent.assigned_distributor&.id

    render json: {
      distributor_id: distributor_id,
      distributor_name: distributor_id ? Distributor.find(distributor_id)&.display_name : nil
    }
  rescue ActiveRecord::RecordNotFound
    render json: { distributor_id: nil, distributor_name: nil }, status: :not_found
  end

  # GET /admin/sub_agents/download
  def download
    format_type = params[:format_type]

    scope = SubAgent.all
    scope = scope.search_by_name_mobile_email(params[:search]) if params[:search].present?
    scope = case params[:status]
            when 'active'   then scope.active
            when 'inactive' then scope.inactive
            else scope
            end
    scope = scope.order(:created_at)

    case format_type
    when 'csv'
      send_data generate_sub_agents_csv(scope), filename: "affiliates_#{Date.current}.csv", type: 'text/csv'
    when 'excel'
      send_data generate_sub_agents_excel(scope),
                filename: "affiliates_#{Date.current}.xlsx",
                type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    else
      redirect_to admin_sub_agents_path, alert: 'Invalid download format.'
    end
  end

  private

  def generate_sub_agents_csv(records)
    require 'csv'
    CSV.generate(headers: true) do |csv|
      csv << %w[ID FirstName MiddleName LastName Mobile Email CompanyName PAN GST
                Address City State BirthDate Gender BankName AccountNo IFSC
                AccountHolderName AccountType UPIID Status CreatedAt]
      records.find_each do |s|
        csv << [s.id, s.first_name, s.middle_name, s.last_name, s.mobile, s.email,
                s.company_name, s.pan_no, s.gst_no, s.address, s.city, s.state,
                s.birth_date, s.gender&.humanize, s.bank_name, s.account_no, s.ifsc_code,
                s.account_holder_name, s.account_type, s.upi_id,
                s.deactivated? ? 'Deactivated' : (s.active? ? 'Active' : 'Inactive'),
                s.created_at.strftime('%Y-%m-%d %H:%M:%S')]
      end
    end
  end

  def generate_sub_agents_excel(records)
    require 'caxlsx'
    package = Axlsx::Package.new
    wb = package.workbook
    hdr = wb.styles.add_style(bg_color: '2E7D32', fg_color: 'FFFFFF', b: true,
                               alignment: { horizontal: :center })
    row = wb.styles.add_style(alignment: { horizontal: :left })
    wb.add_worksheet(name: 'Affiliates') do |sheet|
      sheet.add_row %w[ID FirstName MiddleName LastName Mobile Email CompanyName PAN GST
                       Address City State BirthDate Gender BankName AccountNo IFSC
                       AccountHolderName AccountType UPIID Status CreatedAt], style: hdr
      records.find_each do |s|
        sheet.add_row [s.id, s.first_name, s.middle_name, s.last_name, s.mobile, s.email,
                       s.company_name, s.pan_no, s.gst_no, s.address, s.city, s.state,
                       s.birth_date&.to_s, s.gender&.humanize, s.bank_name, s.account_no,
                       s.ifsc_code, s.account_holder_name, s.account_type, s.upi_id,
                       s.deactivated? ? 'Deactivated' : (s.active? ? 'Active' : 'Inactive'),
                       s.created_at.strftime('%Y-%m-%d %H:%M:%S')], style: row
      end
    end
    package.to_stream.read
  end

  def set_sub_agent
    @sub_agent = SubAgent.includes(:sub_agent_documents).find(params[:id])
  end

  def sub_agent_params
    params.require(:sub_agent).permit(
      :first_name, :middle_name, :last_name, :mobile, :email, :password, :password_confirmation, :role_id,
      :state_id, :city_id, :state, :city, :birth_date, :gender, :pan_no, :gst_no,
      :company_name, :address, :bank_name, :account_no, :ifsc_code,
      :account_holder_name, :account_type, :upi_id, :status, :upload_main_document, :profile_image,
      sub_agent_documents_attributes: [:id, :document_type, :document_file, :_destroy],
      uploaded_documents_attributes: [:id, :title, :description, :document_type, :file, :uploaded_by, :_destroy]
    )
  end

  def generate_affiliate_password
    # Generate password similar to customer creation
    # Format: first 4 letters of name + @ + 4-digit year from DOB
    # Example: RAVI with DOB 15/03/1990 becomes RAVI@1990

    # Get first name - use first_name from sub_agent
    first_name = @sub_agent.first_name.to_s.strip.upcase

    # Get first 4 characters of name, pad with 'X' if less than 4 characters
    name_part = first_name[0..3].ljust(4, 'X')

    # Get birth year from birth_date
    if @sub_agent.birth_date.present?
      year_part = @sub_agent.birth_date.year.to_s
    else
      # Default to current year if no birth date
      year_part = Date.current.year.to_s
    end

    "#{name_part}@#{year_part}"
  end

  def create_user_account_for_sub_agent(sub_agent)
    return unless sub_agent&.email.present?

    existing_user = User.find_by(email: sub_agent.email)
    return if existing_user

    sub_agent_role = Role.find_by(name: 'sub_agent') || Role.find_by(name: 'Sub Agent')

    User.create!(
      first_name: sub_agent.first_name,
      last_name: sub_agent.last_name,
      email: sub_agent.email,
      mobile: sub_agent.mobile,
      password: sub_agent.password,
      password_confirmation: sub_agent.password,
      user_type: 'sub_agent',
      role: sub_agent_role,
      status: true
    )
  rescue => e
    Rails.logger.warn "Failed to create User account for SubAgent #{sub_agent.id}: #{e.message}"
  end

  def handle_distributor_assignment(sub_agent, assigned_distributor_id)
    # Remove existing assignment
    sub_agent.distributor_assignment&.destroy

    # Create new assignment if distributor is selected
    if assigned_distributor_id.present? && assigned_distributor_id != ''
      distributor = Distributor.find_by(id: assigned_distributor_id)
      if distributor
        DistributorAssignment.create!(
          distributor: distributor,
          sub_agent: sub_agent,
          assigned_at: Time.current
        )
      end
    end
  end
end