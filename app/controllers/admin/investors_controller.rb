class Admin::InvestorsController < Admin::ApplicationController
  include LocationData
  include ConfigurablePagination
  before_action :set_investor, only: [:show, :edit, :update, :destroy, :toggle_status, :summary]
  before_action :load_form_data, only: [:new, :edit, :create, :update]

  # GET /admin/investors
  def index
    # Check if search is active first
    search_active = params[:search].present? && params[:search].strip.length >= 4

    @investors = Investor.all

    # Search functionality - only search if 4+ characters or empty
    if params[:search].present?
      search_term = params[:search].strip
      if search_term.length >= 4
        @investors = @investors.search_by_name_mobile_email(search_term) if @investors.respond_to?(:search_by_name_mobile_email)
      elsif search_term.length > 0
        # Return empty result if search term is too short
        @investors = @investors.none
      end
    end

    # Filter by status
    case params[:status]
    when 'active'
      @investors = @investors.active
    when 'inactive'
      @investors = @investors.inactive
    end

    # Get total count before pagination for display purposes
    @total_filtered_count = @investors.count

    # Order and paginate
    @investors = paginate_records(@investors.order(first_name: :asc, last_name: :asc), @total_filtered_count)

    # Calculate statistics using separate scope for stats
    stats_scope = Investor.all

    # Apply filters but handle search differently for stats
    if params[:search].present? && params[:search].strip.length >= 4
      # For statistics, use a simple where clause instead of pg_search to avoid GROUP BY issues
      search_term = params[:search].strip
      stats_scope = stats_scope.where(
        "first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ? OR mobile ILIKE ?",
        "%#{search_term}%", "%#{search_term}%", "%#{search_term}%", "%#{search_term}%"
      )
    end

    case params[:status]
    when 'active'
      stats_scope = stats_scope.active
    when 'inactive'
      stats_scope = stats_scope.inactive
    end

    # Statistics
    @total_investors = stats_scope.count
    @active_investors = stats_scope.active.count
    @inactive_investors = stats_scope.inactive.count

    # Calculate total investor commission amounts (for existing functionality)
    @total_investor_amount = CommissionPayout.where(payout_to: 'investor').sum(:payout_amount) || 0
    @paid_investor_amount = CommissionPayout.where(payout_to: 'investor', status: 'paid').sum(:payout_amount) || 0
    @pending_investor_amount = CommissionPayout.where(payout_to: 'investor', status: 'pending').sum(:payout_amount) || 0

    # Calculate total invested amount from investors (for share calculations)
    @total_invested_amount = stats_scope.where.not(invested_amount: nil).sum(:invested_amount) || 0
  end

  # GET /admin/investors/investor_summary
  def investor_summary
    # Get all investors with their investment data
    @investors = Investor.all.includes(:investor_documents)

    # Calculate comprehensive statistics
    @total_investors = @investors.count
    @active_investors = @investors.active.count
    @inactive_investors = @investors.inactive.count

    # Investment statistics
    @total_invested_amount = @investors.where.not(invested_amount: nil).sum(:invested_amount) || 0
    @average_investment = @total_investors > 0 ? @total_invested_amount / @total_investors : 0

    # Commission pool statistics (Gross Profit)
    @total_commission_pool = CommissionPayout.where(payout_to: 'investor').sum(:payout_amount) || 0
    @paid_commission_amount = CommissionPayout.where(payout_to: 'investor', status: 'paid').sum(:payout_amount) || 0
    @pending_commission_amount = CommissionPayout.where(payout_to: 'investor', status: 'pending').sum(:payout_amount) || 0

    # Share calculations for profit distribution
    @investors_with_shares = @investors.where.not(number_of_shares: nil).where('number_of_shares > 0')
    @total_shares = @investors_with_shares.sum(:number_of_shares) || 0

    # Calculate profit per share
    @profit_per_share = @total_shares > 0 ? @total_commission_pool / @total_shares : 0

    # Get system investment amount
    @system_investment_amount = SystemSetting.investment_amount

    # Calculate detailed profit sharing data for each investor (sorted by shares descending)
    @profit_sharing_data = []
    @investors_with_shares.order(number_of_shares: :desc).each_with_index do |investor, index|
      shares = investor.number_of_shares || 0
      invested_amount = investor.invested_amount || 0

      # Use actual investment percentage from investor table
      sharing_percentage = investor.investment_percentage || 0

      # Calculate profit amount (shares × profit per share)
      profit_amount = shares * @profit_per_share

      # Use actual investment percentage from investor table as profit sharing percentage
      actual_profit_shared_percentage = investor.investment_percentage || 0
      actual_profit_shared = profit_amount * (actual_profit_shared_percentage / 100)

      # Calculate Return on Investment based on actual profit shared vs invested amount
      roi = invested_amount > 0 ? (actual_profit_shared / invested_amount * 100) : 0

      @profit_sharing_data << {
        sl_no: index + 1,
        investor: investor,
        shares: shares,
        invested_amount: invested_amount,
        sharing_percentage: sharing_percentage,
        profit_amount: profit_amount,
        actual_profit_shared_percentage: actual_profit_shared_percentage,
        actual_profit_shared: actual_profit_shared,
        roi: roi
      }
    end

    # Investment performance by percentage
    @investors_with_percentage = @investors.where.not(investment_percentage: nil)
    @total_percentage_allocated = @investors_with_percentage.sum(:investment_percentage) || 0

    # Monthly data for charts (last 12 months)
    @monthly_data = []
    12.times do |i|
      month_start = (Date.current - i.months).beginning_of_month
      month_end = month_start.end_of_month

      investors_count = Investor.where(created_at: month_start..month_end).count
      investment_amount = Investor.where(created_at: month_start..month_end).sum(:invested_amount) || 0

      @monthly_data.unshift({
        month: month_start.strftime('%b %Y'),
        investors_count: investors_count,
        investment_amount: investment_amount
      })
    end

    # Top investors by investment amount
    @top_investors_by_amount = @investors.where.not(invested_amount: nil)
                                        .order(invested_amount: :desc)
                                        .limit(10)

    # Top investors by percentage
    @top_investors_by_percentage = @investors.where.not(investment_percentage: nil)
                                            .order(investment_percentage: :desc)
                                            .limit(10)
  end

  # GET /admin/investors/1/summary
  def summary
    # Find only ambassadors (distributors) explicitly linked to this investor.
    ambassadors = begin
      Distributor.where(investor_id: @investor.id).order(:created_at)
    rescue => e
      Rails.logger.warn "investor_id column missing on distributors: #{e.message}"
      Distributor.none
    end

    policy_classes = [['health', HealthInsurance], ['life', LifeInsurance], ['motor', MotorInsurance]]

    @investor_commission_paid    = 0.0
    @investor_commission_pending = 0.0
    @investor_commission_rows    = []

    @ambassador_rows = ambassadors.map do |amb|
      name = amb.display_name.presence || "#{amb.first_name} #{amb.last_name}".strip.presence || "Ambassador ##{amb.id}"

      amb_paid       = 0.0
      amb_pending    = 0.0
      policies_count = 0
      amb_premium    = 0.0
      amb_policy_rows = []

      policy_classes.each do |ptype, klass|
        tbl = klass.table_name
        klass.where(distributor_id: amb.id).includes(:customer).each do |pol|
          payout = CommissionPayout.where(
            policy_type: ptype, policy_id: pol.id, payout_to: 'ambassador'
          ).order(created_at: :desc).first

          premium       = pol.total_premium.to_f
          comm_pct      = pol.try(:ambassador_commission_percentage).to_f
          gross         = pol.try(:ambassador_commission_amount).to_f
          tds_pct       = pol.try(:ambassador_tds_percentage).to_f
          tds_amt       = pol.try(:ambassador_tds_amount).to_f
          after_tds     = pol.try(:ambassador_after_tds_value).to_f
          after_tds     = (gross - tds_amt).round(2) if after_tds.zero? && gross > 0
          net           = payout&.payout_amount.to_f
          p_paid        = payout&.paid?    ? net : 0.0
          p_pending     = payout&.pending? ? net : 0.0

          inv_payout  = CommissionPayout.where(policy_type: ptype, policy_id: pol.id, payout_to: 'investor').order(created_at: :desc).first
          inv_gross   = pol.try(:investor_commission_amount).to_f
          inv_tds_pct = pol.try(:investor_tds_percentage).to_f
          inv_tds     = pol.try(:investor_tds_amount).to_f
          inv_aft     = pol.try(:investor_after_tds_value).to_f
          inv_aft     = (inv_gross - inv_tds).round(2) if inv_aft.zero? && inv_gross > 0
          inv_net     = inv_payout&.payout_amount.to_f
          pol_investor_id = pol.try(:investor_id)
          if pol_investor_id.nil? || pol_investor_id == @investor.id
            @investor_commission_paid    += inv_payout&.paid?    ? inv_net : 0.0
            @investor_commission_pending += inv_payout&.pending? ? inv_net : 0.0
            @investor_commission_rows << {
              policy_id:     pol.id,
              policy_slug:   ptype,
              policy_number: pol.policy_number.presence || '—',
              customer_name: pol.customer&.display_name.presence || 'N/A',
              type:          ptype.capitalize,
              source:        "Ambassador: #{name}",
              premium:       premium,
              inv_comm_pct:  pol.try(:investor_commission_percentage).to_f,
              inv_gross:     inv_gross,
              inv_tds_pct:   inv_tds_pct,
              inv_tds:       inv_tds,
              inv_after_tds: inv_aft,
              inv_net:       inv_net,
              inv_status:    inv_payout&.status || 'no_payout',
              payout_date:   inv_payout&.payout_date&.strftime('%d %b %Y')
            }
          end

          amb_paid       += p_paid
          amb_pending    += p_pending
          policies_count += 1
          amb_premium    += premium

          amb_policy_rows << {
            policy_number:    pol.policy_number.presence || '—',
            customer_name:    pol.customer&.display_name.presence || 'N/A',
            type:             ptype.capitalize,
            premium:          premium,
            comm_percentage:  comm_pct,
            gross_commission: gross,
            tds_percentage:   tds_pct,
            tds_amount:       tds_amt,
            after_tds:        after_tds,
            net_commission:   net,
            status:           payout&.status || 'no_payout',
            payout_date:      payout&.payout_date&.strftime('%d %b %Y'),
            inv_comm_pct:     pol.try(:investor_commission_percentage).to_f,
            inv_gross:        inv_gross,
            inv_tds_pct:      inv_tds_pct,
            inv_tds:          inv_tds,
            inv_after_tds:    inv_aft,
            inv_status:       inv_payout&.status || 'no_payout'
          }
        end rescue nil
      end

      # Affiliates: combine assigned (via junction table) + direct (via distributor_id)
      assigned_ids = amb.assigned_sub_agents.pluck(:id) rescue []
      direct_ids   = amb.sub_agents.pluck(:id) rescue []
      all_af_ids   = (assigned_ids + direct_ids).uniq
      affiliates   = SubAgent.where(id: all_af_ids).order(:created_at)

      aff_rows = affiliates.map do |af|
        af_name    = af.display_name.presence || "#{af.first_name} #{af.last_name}".strip.presence || "Affiliate ##{af.id}"
        af_paid    = 0.0
        af_pending = 0.0
        af_policies = 0
        af_premium  = 0.0
        af_policy_rows = []

        policy_classes.each do |ptype, klass|
          tbl = klass.table_name
          klass.where(sub_agent_id: af.id).includes(:customer).each do |pol|
            payout = CommissionPayout.where(
              policy_type: ptype, policy_id: pol.id,
              payout_to: ['sub_agent', 'affiliate']
            ).order(created_at: :desc).first

            premium      = pol.total_premium.to_f
            comm_pct     = pol.try(:sub_agent_commission_percentage).to_f
            gross        = pol.try(:sub_agent_commission_amount).to_f
            tds_pct      = pol.try(:sub_agent_tds_percentage).to_f
            tds_amt      = pol.try(:sub_agent_tds_amount).to_f
            after_tds    = pol.try(:sub_agent_after_tds_value).to_f
            after_tds    = (gross - tds_amt).round(2) if after_tds.zero? && gross > 0
            net          = payout&.payout_amount.to_f
            p_paid       = payout&.paid?    ? net : 0.0
            p_pending    = payout&.pending? ? net : 0.0

            amb_pol_pay = CommissionPayout.where(policy_type: ptype, policy_id: pol.id, payout_to: 'ambassador').order(created_at: :desc).first
            amb_g       = pol.try(:ambassador_commission_amount).to_f
            amb_t       = pol.try(:ambassador_tds_amount).to_f
            amb_a       = pol.try(:ambassador_after_tds_value).to_f
            amb_a       = (amb_g - amb_t).round(2) if amb_a.zero? && amb_g > 0

            inv_payout  = CommissionPayout.where(policy_type: ptype, policy_id: pol.id, payout_to: 'investor').order(created_at: :desc).first
            inv_gross   = pol.try(:investor_commission_amount).to_f
            inv_tds_pct = pol.try(:investor_tds_percentage).to_f
            inv_tds     = pol.try(:investor_tds_amount).to_f
            inv_aft     = pol.try(:investor_after_tds_value).to_f
            inv_aft     = (inv_gross - inv_tds).round(2) if inv_aft.zero? && inv_gross > 0
            inv_net     = inv_payout&.payout_amount.to_f
            pol_investor_id = pol.try(:investor_id)
            if pol_investor_id.nil? || pol_investor_id == @investor.id
              @investor_commission_paid    += inv_payout&.paid?    ? inv_net : 0.0
              @investor_commission_pending += inv_payout&.pending? ? inv_net : 0.0
              @investor_commission_rows << {
                policy_id:     pol.id,
                policy_slug:   ptype,
                policy_number: pol.policy_number.presence || '—',
                customer_name: pol.customer&.display_name.presence || 'N/A',
                type:          ptype.capitalize,
                source:        "#{name} → #{af_name}",
                premium:       premium,
                inv_comm_pct:  pol.try(:investor_commission_percentage).to_f,
                inv_gross:     inv_gross,
                inv_tds_pct:   inv_tds_pct,
                inv_tds:       inv_tds,
                inv_after_tds: inv_aft,
                inv_net:       inv_net,
                inv_status:    inv_payout&.status || 'no_payout',
                payout_date:   inv_payout&.payout_date&.strftime('%d %b %Y')
              }
            end

            af_paid      += p_paid
            af_pending   += p_pending
            af_policies  += 1
            af_premium   += premium

            af_policy_rows << {
              policy_number:    pol.policy_number.presence || '—',
              customer_name:    pol.customer&.display_name.presence || 'N/A',
              type:             ptype.capitalize,
              premium:          premium,
              comm_percentage:  comm_pct,
              gross_commission: gross,
              tds_percentage:   tds_pct,
              tds_amount:       tds_amt,
              after_tds:        after_tds,
              net_commission:   net,
              status:           payout&.status || 'no_payout',
              payout_date:      payout&.payout_date&.strftime('%d %b %Y'),
              amb_comm_pct:     pol.try(:ambassador_commission_percentage).to_f,
              amb_gross:        amb_g,
              amb_tds_pct:      pol.try(:ambassador_tds_percentage).to_f,
              amb_tds:          amb_t,
              amb_after_tds:    amb_a,
              amb_status:       amb_pol_pay&.status || 'no_payout',
              inv_comm_pct:     pol.try(:investor_commission_percentage).to_f,
              inv_gross:        inv_gross,
              inv_tds_pct:      inv_tds_pct,
              inv_tds:          inv_tds,
              inv_after_tds:    inv_aft,
              inv_status:       inv_payout&.status || 'no_payout'
            }
          end rescue nil
        end

        {
          affiliate: af,
          name: af_name,
          policies: af_policies,
          premium: af_premium,
          commission_paid: af_paid,
          commission_pending: af_pending,
          total_commission: af_paid + af_pending,
          policy_rows: af_policy_rows
        }
      end

      {
        ambassador: amb,
        name: name,
        policies: policies_count,
        premium: amb_premium,
        commission_paid: amb_paid,
        commission_pending: amb_pending,
        total_commission: amb_paid + amb_pending,
        affiliates_count: affiliates.count,
        affiliates: aff_rows,
        policy_rows: amb_policy_rows
      }
    end

    # Policies directly linked to this investor (health + motor have investor_id)
    health_policies = HealthInsurance.where(investor_id: @investor.id).includes(:customer).order(created_at: :desc) rescue []
    motor_policies  = MotorInsurance.where(investor_id: @investor.id).includes(:customer).order(created_at: :desc) rescue []

    @direct_policies = []
    health_policies.each { |p| @direct_policies << { policy: p, type: 'Health', premium: p.total_premium.to_f } }
    motor_policies.each  { |p| @direct_policies << { policy: p, type: 'Motor',  premium: p.total_premium.to_f } }

    # Investor commission is accumulated per-policy inside the ambassador/affiliate loops above.
    # Supplement with any policies linked directly via investor_id (not already in network).
    network_policy_ids_by_type = @ambassador_rows.each_with_object(Hash.new { |h, k| h[k] = [] }) do |row, h|
      (row[:policy_rows] + row[:affiliates].flat_map { |a| a[:policy_rows] }).each do |pr|
        # policy_rows don't store policy_id yet — skip to avoid double-counting; rely on inline accumulation
      end
    end

    # Aggregated totals
    @total_ambassadors       = @ambassador_rows.size
    @total_affiliates        = @ambassador_rows.sum { |r| r[:affiliates_count] }
    @total_ambassador_comm   = @ambassador_rows.sum { |r| r[:total_commission] }
    @total_affiliate_comm    = @ambassador_rows.sum { |r| r[:affiliates].sum { |a| a[:total_commission] } }
    @total_network_premium   = @ambassador_rows.sum { |r| r[:premium] + r[:affiliates].sum { |a| a[:premium] } }
    @total_direct_premium    = @direct_policies.sum { |p| p[:premium] }
    @total_direct_policies   = @direct_policies.size
  end

  # GET /admin/investors/1
  def show
    @documents = @investor.investor_documents.order(:created_at)
  end

  # GET /admin/investors/new
  def new
    @investor = Investor.new
    @investor.role_id = 'investor'
    @investor.investor_documents.build
  end

  # GET /admin/investors/1/edit
  def edit
    # Don't build empty documents in edit - let user add them via JavaScript
  end

  # POST /admin/investors
  def create
    # Extract documents and main file from params to handle R2 upload separately
    documents_attributes = investor_params[:investor_documents_attributes]
    investor_data = investor_params.except(:upload_main_document, :investor_documents_attributes)
    @investor = Investor.new(investor_data)
    @investor.role_id = 'investor'

    if @investor.save
      # Create corresponding User account for investor authentication
      create_investor_user_account(@investor)

      # Handle R2 file upload for main document
      handle_r2_upload(@investor) if params[:investor][:upload_main_document].present?

      # Handle nested documents upload to R2
      handle_nested_documents_r2_upload(documents_attributes) if documents_attributes.present?

      redirect_to admin_investors_path, notice: 'Investor was successfully created.'
    else
      # Build a new document for the form if none exist
      @investor.investor_documents.build if @investor.investor_documents.empty?
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /admin/investors/1
  def update
    # Handle R2 document deletion
    if params[:delete_document] == 'true'
      if @investor.has_r2_document?
        @investor.delete_from_r2
        redirect_to edit_admin_investor_path(@investor), notice: 'Document was successfully deleted.'
        return
      else
        redirect_to edit_admin_investor_path(@investor), alert: 'No document to delete.'
        return
      end
    end

    # Handle password reset
    if params[:reset_password] == 'true' || params[:reset_password] == '1'
      if params[:new_password_option] == 'manual' && investor_params[:password].present?
        # Manual password provided
        @investor.password = investor_params[:password]
        @investor.original_password = investor_params[:password]
      else
        # Auto-generate new password
        new_password = "Ganesha@123"
        @investor.password = new_password
        @investor.original_password = new_password
      end
    end

    # Extract new documents from params to handle R2 upload separately
    documents_attributes = investor_params[:investor_documents_attributes]
    update_params = investor_params.except(:upload_main_document, :investor_documents_attributes)
    unless params[:reset_password] == 'true' || params[:reset_password] == '1'
      update_params = update_params.except(:password, :password_confirmation)
    end

# Debug logging (temporarily enabled for troubleshooting)
    Rails.logger.info "=== INVESTOR UPDATE DEBUG ==="
    Rails.logger.info "Documents attributes: #{documents_attributes.inspect}"
    Rails.logger.info "Documents present: #{documents_attributes.present?}"
    Rails.logger.info "Raw params documents: #{params[:investor][:investor_documents_attributes].inspect}"

    if @investor.update(update_params)
      # Handle R2 file upload for main document
      handle_r2_upload(@investor) if params[:investor][:upload_main_document].present?

      # Handle nested documents upload to R2
      if documents_attributes.present?
        Rails.logger.info "Processing #{documents_attributes.keys.length} document(s)"
        handle_nested_documents_r2_upload(documents_attributes)
      else
        Rails.logger.info "No documents to process"
      end

      if params[:reset_password] == 'true' || params[:reset_password] == '1'
        redirect_to admin_investors_path, notice: 'Investor was successfully updated and password was reset.'
      else
        redirect_to admin_investors_path, notice: 'Investor was successfully updated.'
      end
    else
      # Don't build empty documents on error - just re-render
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/investors/1
  def destroy
    begin
      # Simply delete the investor record only
      investor_name = @investor.display_name
      @investor.destroy!

      redirect_to admin_investors_path, notice: "Investor #{investor_name} was successfully deleted."

    rescue StandardError => e
      Rails.logger.error "Failed to delete investor #{@investor.id}: #{e.message}"
      redirect_to admin_investors_path, alert: "Failed to delete investor: #{e.message}"
    end
  end

  # PATCH /admin/investors/1/toggle_status
  def toggle_status
    new_status = @investor.active? ? :inactive : :active

    if @investor.update(status: new_status)
      redirect_to admin_investors_path, notice: "Investor status updated to #{new_status}."
    else
      redirect_to admin_investors_path, alert: 'Failed to update status.'
    end
  end

  private

  def set_investor
    @investor = Investor.find(params[:id])
  end

  def load_form_data
    # Load states and cities data for the form
    @states_for_select = LocationData.states_for_select
  end

  def investor_params
    params.require(:investor).permit(
      :first_name, :middle_name, :last_name, :mobile, :email, :role_id,
      :state, :city, :birth_date, :gender, :pan_no, :gst_no,
      :company_name, :address, :bank_name, :account_no, :ifsc_code,
      :account_holder_name, :account_type, :upi_id, :status,
      :username, :password, :password_confirmation, :original_password,
      :number_of_shares, :invested_amount, :investment_percentage,
      investor_documents_attributes: [:id, :document_type, :document_file, :_destroy]
    )
  end

  # R2 Upload Helper
  def handle_r2_upload(investor)
    file = params[:investor][:upload_main_document]
    return unless file.present?

    # Delete old R2 file if exists
    investor.delete_from_r2 if investor.has_r2_document?

    # Upload new file to R2
    result = investor.upload_to_r2(file)

    if result.is_a?(Hash) && !result[:error]
      flash[:notice] = (flash[:notice] || '') + " File uploaded successfully to R2."
    elsif result.is_a?(Hash) && result[:error]
      error_msg = result[:error]
      flash[:alert] = (flash[:alert] || '') + " File upload failed: #{error_msg}"
    elsif result == false
      flash[:alert] = (flash[:alert] || '') + " File upload failed: Unknown error"
    else
      flash[:notice] = (flash[:notice] || '') + " File uploaded successfully to R2."
    end
  end

  # R2 Upload Helper for nested documents
  def handle_nested_documents_r2_upload(documents_attributes)
    return unless documents_attributes.present?

    Rails.logger.info "=== NESTED DOCUMENTS UPLOAD DEBUG ==="
    Rails.logger.info "Documents attributes: #{documents_attributes.inspect}"

    uploaded_count = 0
    error_count = 0

    documents_attributes.each do |index, document_attrs|
      Rails.logger.info "Processing document #{index}: #{document_attrs.inspect}"

      unless document_attrs[:document_file].present? && document_attrs[:document_type].present?
        Rails.logger.info "Skipping document #{index}: missing file or type"
        next
      end

      Rails.logger.info "Creating document: type=#{document_attrs[:document_type]}, file=#{document_attrs[:document_file].original_filename}"

      file = document_attrs[:document_file]

      # First upload to R2
      Rails.logger.info "Uploading file to R2..."
      result = R2Service.upload(file, folder: "investors/#{@investor.id}/documents")
      Rails.logger.info "R2 upload result: #{result.inspect}"

      if result[:error]
        Rails.logger.error "R2 upload failed: #{result[:error]}"
        error_count += 1
        next
      end

      # Create document with R2 information
      document = @investor.investor_documents.build(
        document_type: document_attrs[:document_type],
        r2_file_key: result[:key],
        r2_filename: result[:filename],
        r2_content_type: result[:content_type],
        r2_file_size: result[:size]
      )

      if document.save
        Rails.logger.info "Document saved with ID: #{document.id}"
        uploaded_count += 1
      else
        Rails.logger.error "Document save failed: #{document.errors.full_messages}"
        # Delete the uploaded file from R2 since document save failed
        R2Service.delete(result[:key])
        error_count += 1
      end
    end

    Rails.logger.info "Upload summary: #{uploaded_count} uploaded, #{error_count} failed"

    # Add flash messages for upload results
    if uploaded_count > 0
      flash[:notice] = (flash[:notice] || '') + " #{uploaded_count} document(s) uploaded successfully to R2."
    end

    if error_count > 0
      flash[:alert] = (flash[:alert] || '') + " #{error_count} document(s) failed to upload."
    end
  end

  # Create User account for investor authentication
  def create_investor_user_account(investor)
    return if User.find_by(email: investor.email) # Skip if user already exists

    # Get investor role (create if not exists)
    investor_role = Role.find_by(name: 'investor')
    if investor_role.nil?
      investor_role = Role.create!(
        name: 'investor',
        description: 'Investor role for profit sharing dashboard access',
        status: 'active'
      )
    end

    # Use investor's password or default
    password = investor.original_password.presence || 'Ganesha@123'

    # Create User account
    user = User.new(
      email: investor.email,
      first_name: investor.first_name,
      last_name: investor.last_name,
      mobile: investor.mobile,
      user_type: 'investor',
      role: investor_role,
      password: password,
      password_confirmation: password
    )

    if user.save
      Rails.logger.info "✅ Created User account for investor: #{investor.email}"
      flash[:notice] = (flash[:notice] || '') + " User account created for investor login."
    else
      Rails.logger.error "❌ Failed to create User account for investor #{investor.email}: #{user.errors.full_messages}"
      flash[:alert] = (flash[:alert] || '') + " Warning: Could not create user account for investor login."
    end
  end
end
