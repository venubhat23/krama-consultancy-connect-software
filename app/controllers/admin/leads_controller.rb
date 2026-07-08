class Admin::LeadsController < Admin::ApplicationController
  include LocationData
  include ConfigurablePagination
  before_action :set_lead, only: [:show, :edit, :update, :destroy, :convert_to_customer, :convert_to_customer_branch_out, :create_policy, :transfer_referral, :advance_stage, :go_back_stage, :update_stage, :convert_stage, :mark_not_interested, :close_lead]

  # Skip authentication for AJAX endpoints used in forms
  skip_before_action :authenticate_user!, only: [:check_existing_customer, :search_sub_agents]
  skip_before_action :ensure_admin, only: [:check_existing_customer, :search_sub_agents]

  # GET /admin/leads
  def index
    # Handle tab-based filtering
    case params[:tab]
    when 'converted'
      # Show only converted leads (those with converted stage), sorted by latest updated first
      @leads = Lead.where(current_stage: 'converted').order(stage_updated_at: :desc, updated_at: :desc)
      params[:show_converted] = 'true'  # For backward compatibility
    else
      # Default: Show active leads (all except converted stage)
      if params[:show_converted] == 'true'
        @leads = Lead.all
      else
        @leads = Lead.where.not(current_stage: 'converted')
      end
    end

    # Search functionality - Use simpler search in production for better performance
    if params[:search].present?
      if Rails.env.production? && @leads.respond_to?(:simple_search)
        @leads = @leads.simple_search(params[:search])
      else
        @leads = @leads.search_leads(params[:search])
      end
    end

    # Filter by current stage
    if params[:current_stage].present?
      @leads = @leads.by_stage(params[:current_stage])
    end

    # Filter by lead source
    if params[:lead_source].present?
      @leads = @leads.by_source(params[:lead_source])
    end

    # Filter by product category
    if params[:product_category].present?
      @leads = @leads.by_product_category(params[:product_category])
    end

    # Filter by product subcategory
    if params[:product_subcategory].present?
      @leads = @leads.by_product_subcategory(params[:product_subcategory])
    end

    # Filter by referred by
    if params[:referred_by].present?
      @leads = @leads.where("referred_by ILIKE ?", "%#{params[:referred_by]}%")
    end

    # Apply ordering only if not already ordered (e.g., for converted leads)
    if params[:tab] == 'converted'
      @leads = paginate_records(@leads.includes(:converted_customer, :created_policy, :affiliate, :ambassador))
    else
      @leads = paginate_records(@leads.order(created_at: :desc).includes(:converted_customer, :created_policy, :affiliate, :ambassador))
    end

    # Statistics — all stage counts in one query instead of 7 separate count queries
    stats = ActiveRecord::Base.connection.execute(<<~SQL).first
      SELECT
        COUNT(*) FILTER (WHERE current_stage != 'converted')                    AS total_active,
        COUNT(*) FILTER (WHERE current_stage = 'lead_generated')                AS lead_generated,
        COUNT(*) FILTER (WHERE current_stage = 'consultation_scheduled')        AS consultation,
        COUNT(*) FILTER (WHERE current_stage = 'one_on_one')                    AS one_on_one,
        COUNT(*) FILTER (WHERE current_stage = 'follow_up')                     AS follow_up,
        COUNT(*) FILTER (WHERE current_stage = 'converted')                     AS converted,
        COUNT(*) FILTER (WHERE current_stage = 'lead_closed')                   AS lead_closed
      FROM leads
    SQL
    @total_leads          = stats['total_active'].to_i
    @lead_generated_leads = stats['lead_generated'].to_i
    @consultation_leads   = stats['consultation'].to_i
    @one_on_one_leads     = stats['one_on_one'].to_i
    @follow_up_leads      = stats['follow_up'].to_i
    @converted_leads      = stats['converted'].to_i
    @lead_closed_leads    = stats['lead_closed'].to_i

    # Conversion rate calculation
    total_converted = @converted_leads
    @conversion_rate = @total_leads > 0 ? (total_converted.to_f / @total_leads * 100).round(1) : 0

    # Pipeline stats
    @pipeline_stats = {
      lead_generated: @lead_generated_leads,
      consultation_scheduled: @consultation_leads,
      one_on_one: @one_on_one_leads,
      follow_up: @follow_up_leads,
      converted: @converted_leads,
      lead_closed: @lead_closed_leads
    }

    # Temporarily use simple view for debugging
    if params[:debug] == 'simple'
      render 'index_simple'
    end
  end

  # GET /admin/leads/kanban
  def kanban
    # Load leads grouped by stage for Kanban board, ordered by latest updated first
    leads = Lead.includes(:converted_customer, :affiliate)
                .order(stage_updated_at: :desc, updated_at: :desc, created_at: :desc)

    # Group by stage while maintaining sort order within each group
    @leads_by_stage = leads.group_by(&:current_stage)

    # Ensure each group is properly sorted with newest leads at top
    @leads_by_stage.each do |stage, stage_leads|
      @leads_by_stage[stage] = stage_leads.sort do |a, b|
        # Primary sort: stage_updated_at (newest first)
        stage_comparison = (b.stage_updated_at || b.created_at) <=> (a.stage_updated_at || a.created_at)
        if stage_comparison == 0
          # Secondary sort: updated_at (newest first)
          updated_comparison = b.updated_at <=> a.updated_at
          if updated_comparison == 0
            # Tertiary sort: created_at (newest first)
            b.created_at <=> a.created_at
          else
            updated_comparison
          end
        else
          stage_comparison
        end
      end
    end
    # Get stage definitions with display names and colors
    @stages = {
      'lead_generated' => { name: 'Lead Generated', color: 'primary' },
      'consultation_scheduled' => { name: 'Consultation', color: 'info' },
      'one_on_one' => { name: 'One-on-One', color: 'warning' },
      'follow_up' => { name: 'Follow-Up Successful', color: 'secondary' },
      'converted' => { name: 'Converted', color: 'success' },
      'follow_up_unsuccessful' => { name: 'Follow-Up Failed', color: 'danger' },
      'not_interested' => { name: 'Not Interested', color: 'dark' },
      're_follow_up' => { name: 'Re-Follow Up', color: 'warning' },
      'lead_closed' => { name: 'Closed', color: 'secondary' }
    }
  end

  # GET /admin/leads/kanban_flow
  def kanban_flow
    # Load leads grouped by stage for Kanban board, ordered by latest updated first
    leads = Lead.includes(:converted_customer, :affiliate)
                .order(stage_updated_at: :desc, updated_at: :desc, created_at: :desc)

    # Group by stage while maintaining sort order within each group
    @leads_by_stage = leads.group_by(&:current_stage)

    # Ensure each group is properly sorted with newest leads at top
    @leads_by_stage.each do |stage, stage_leads|
      @leads_by_stage[stage] = stage_leads.sort do |a, b|
        # Primary sort: stage_updated_at (newest first)
        stage_comparison = (b.stage_updated_at || b.created_at) <=> (a.stage_updated_at || a.created_at)
        if stage_comparison == 0
          # Secondary sort: updated_at (newest first)
          updated_comparison = b.updated_at <=> a.updated_at
          if updated_comparison == 0
            # Tertiary sort: created_at (newest first)
            b.created_at <=> a.created_at
          else
            updated_comparison
          end
        else
          stage_comparison
        end
      end
    end

    # Get stage definitions with display names and colors
    @stages = {
      'lead_generated' => { name: 'Lead Generated', color: 'primary' },
      'consultation_scheduled' => { name: 'Consultation', color: 'info' },
      'one_on_one' => { name: 'One-on-One', color: 'warning' },
      'follow_up' => { name: 'Follow-Up Successful', color: 'secondary' },
      'converted' => { name: 'Converted', color: 'success' },
      'follow_up_unsuccessful' => { name: 'Follow-Up Failed', color: 'danger' },
      'not_interested' => { name: 'Not Interested', color: 'dark' },
      're_follow_up' => { name: 'Re-Follow Up', color: 'warning' },
      'lead_closed' => { name: 'Closed', color: 'secondary' }
    }
  end

  # GET /admin/leads/1
  def show
    @activity_logs = []
  end

  # GET /admin/leads/new
  def new
    # Clear any existing branch out session data when accessing regular new lead form
    session.delete(:branch_out_mode)
    session.delete(:source_lead_id)
    session.delete(:source_customer_id)

    @lead = Lead.new
    @lead.created_date = Date.current
    @lead.current_stage = 'lead_generated'
  end

  # GET /admin/leads/1/edit
  def edit
  end

  # POST /admin/leads
  def create
    @lead = Lead.new(lead_params)
    @lead.created_date = Date.current if @lead.created_date.blank?

    # Set is_branch_out flag and parent_lead_id if in branch out mode
    if session[:branch_out_mode] && session[:source_lead_id]
      @lead.is_branch_out = true
      @lead.parent_lead_id = session[:source_lead_id]

      # Copy affiliate and ambassador from parent lead if not explicitly set
      source_lead = Lead.find_by(id: session[:source_lead_id])
      if source_lead
        @lead.affiliate_id ||= source_lead.affiliate_id
        @lead.ambassador_id ||= source_lead.ambassador_id
      end
    end

    if @lead.save
      # Handle branch out mode
      if session[:branch_out_mode] && session[:source_lead_id]
        source_lead = Lead.find_by(id: session[:source_lead_id])
        if source_lead
          # Add reference note to both leads
          @lead.update(notes: "#{@lead.notes}\n\nBranched from: #{source_lead.lead_id} (#{source_lead.product_category}/#{source_lead.product_subcategory})")
          source_lead.update(notes: "#{source_lead.notes}\n\nBranched to: #{@lead.lead_id} (#{@lead.product_category}/#{@lead.product_subcategory})")
        end

        # Clear session data
        session.delete(:source_lead_id)
        session.delete(:source_customer_id)
        session.delete(:branch_out_mode)
      end

      redirect_to admin_leads_path, notice: 'Lead was successfully created.'
    else
      Rails.logger.error "Lead creation failed: #{@lead.errors.full_messages.join(', ')}"
      flash.now[:alert] = "Failed to create lead: #{@lead.errors.full_messages.join(', ')}"
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /admin/leads/1
  def update
    if @lead.update(lead_params)
      redirect_to admin_lead_path(@lead), notice: 'Lead was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/leads/1
  def destroy
    deletion_result = validate_lead_deletion(@lead)

    if deletion_result[:can_delete]
      # Lead can be safely deleted - delete all associated data
      begin
        ActiveRecord::Base.transaction do
          # Delete uploaded documents
          @lead.uploaded_documents.destroy_all if @lead.uploaded_documents.any?

          # Clean up parent-branch relationships
          if @lead.is_branch_out?
            # Remove branch lead reference from parent
            @lead.update_column(:parent_lead_id, nil) if @lead.parent_lead_id.present?
          else
            # Remove parent reference from branch leads
            @lead.branch_out_leads.update_all(parent_lead_id: nil) if @lead.branch_out_leads.any?
          end

          # Delete the lead itself
          @lead.destroy!
        end

        respond_to do |format|
          format.html { redirect_to admin_leads_path, notice: 'Lead successfully deleted.' }
          format.json { render json: { success: true, message: 'Lead successfully deleted' } }
        end
      rescue ActiveRecord::RecordNotDestroyed => e
        respond_to do |format|
          format.html { redirect_to admin_leads_path, alert: "Failed to delete lead: #{e.message}" }
          format.json { render json: { success: false, message: "Failed to delete lead: #{e.message}" } }
        end
      rescue => e
        respond_to do |format|
          format.html { redirect_to admin_leads_path, alert: "Failed to delete lead: #{e.message}" }
          format.json { render json: { success: false, message: "Failed to delete lead: #{e.message}" } }
        end
      end
    else
      respond_to do |format|
        format.html { redirect_to admin_leads_path, alert: deletion_result[:message] }
        format.json { render json: { success: false, message: deletion_result[:message] } }
      end
    end
  end

  # PATCH /admin/leads/1/convert_to_customer_branch_out - Special handling for branch out leads
  def convert_to_customer_branch_out
    unless @lead.can_convert_to_customer?
      redirect_to admin_leads_path, alert: 'Lead cannot be converted at this stage.'
      return
    end

    unless @lead.is_branch_out? && @lead.parent_lead_id.present?
      redirect_to admin_leads_path, alert: 'This action is only available for branch out leads.'
      return
    end

    # Find parent lead
    parent_lead = Lead.find_by(id: @lead.parent_lead_id)
    unless parent_lead
      redirect_to admin_leads_path, alert: 'Parent lead not found.'
      return
    end

    # Try to find an existing customer - from parent lead or by contact/email
    existing_customer = nil

    # First check if parent lead has a converted customer
    if parent_lead.converted_customer_id.present?
      existing_customer = Customer.find_by(id: parent_lead.converted_customer_id)
    end

    # If no customer from parent lead, check by contact number or email
    if existing_customer.nil?
      if @lead.contact_number.present?
        existing_customer = Customer.find_by(mobile: @lead.contact_number)
      end

      if existing_customer.nil? && @lead.email.present?
        existing_customer = Customer.find_by(email: @lead.email)
      end
    end

    begin
      if existing_customer
        # Update the branch out lead to mark as converted and link to existing customer
        @lead.update!(
          current_stage: 'converted',
          converted_customer_id: existing_customer.id
        )

        # Redirect to product selection page for branch out leads with existing customers
        redirect_to product_selection_admin_customer_path(existing_customer),
                    notice: "Branch out lead linked to existing customer. Please select a product to continue."
      else
        # No existing customer found, redirect to regular convert_to_customer action
        redirect_to convert_to_customer_admin_lead_path(@lead),
                    notice: "No existing customer found. Please proceed with creating a new customer."
      end
    rescue => e
      Rails.logger.error "Branch out lead conversion failed: #{e.message}"
      redirect_to admin_leads_path, alert: "Failed to convert branch out lead: #{e.message}"
    end
  end

  # GET & PATCH /admin/leads/1/convert_to_customer
  def convert_to_customer
    unless @lead.can_convert_to_customer?
      redirect_to admin_lead_path(@lead), alert: 'Lead cannot be converted at this stage.'
      return
    end

    # Handle GET request - show conversion form
    if request.get?
      @existing_customer = find_existing_customer_for_lead(@lead)
      @conversion_context = determine_conversion_context(@lead, @existing_customer)
      return # This will render convert_to_customer.html.erb
    end

    # Handle PATCH request - process conversion
    existing_customer = find_existing_customer_for_lead(@lead)

    # Check if user clicked "continue_with_existing" parameter
    if params[:continue_with_existing] && existing_customer
      link_lead_to_existing_customer(@lead, existing_customer)
      redirect_to_insurance_creation(@lead, existing_customer)
      return
    end

    if existing_customer
      # Show existing customer found - redirect back to conversion page with alert
      flash[:alert] = "Customer already exists for this #{@lead.is_branch_out? ? 'branch' : 'parent'} lead."
      redirect_to convert_to_customer_admin_lead_path(@lead)
      return
    end

    # No existing customer, proceed with creating new customer
    redirect_to new_admin_customer_path(lead_id: @lead.id),
                notice: "Please create a new customer from this lead."
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Lead conversion failed for lead #{@lead.id}: #{e.message}"
    redirect_to admin_lead_path(@lead), alert: "Failed to convert lead: #{e.message}"
  end

  # PATCH /admin/leads/1/create_policy
  def create_policy
    unless @lead.can_create_policy?
      redirect_to admin_lead_path(@lead), alert: 'Cannot create policy for this lead.'
      return
    end

    if @lead.product_category == 'insurance'
      case @lead.product_subcategory
      when 'health'
        redirect_to new_admin_health_insurance_path(customer_id: @lead.converted_customer_id, lead_id: @lead.id)
      when 'life'
        redirect_to new_admin_life_insurance_path(customer_id: @lead.converted_customer_id, lead_id: @lead.id)
      when 'motor'
        redirect_to new_admin_motor_insurance_path(customer_id: @lead.converted_customer_id, lead_id: @lead.id)
      when 'general', 'travel', 'other'
        redirect_to new_admin_other_insurance_path(customer_id: @lead.converted_customer_id, lead_id: @lead.id)
      else
        redirect_to admin_lead_path(@lead), alert: 'Unknown insurance type.'
      end
    else
      redirect_to admin_lead_path(@lead), alert: 'Policy creation is only available for insurance products.'
    end
  end

  # PATCH /admin/leads/1/transfer_referral
  def transfer_referral
    unless @lead.can_settle_referral?
      redirect_to admin_lead_path(@lead), alert: 'Referral cannot be settled at this stage.'
      return
    end

    ActiveRecord::Base.transaction do
      @lead.update!(
        current_stage: 'referral_settled',
        transferred_amount: true
      )

      redirect_to admin_lead_path(@lead), notice: 'Referral payment transferred successfully.'
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_lead_path(@lead), alert: "Failed to transfer referral: #{e.message}"
  end

  # PATCH /admin/leads/1/advance_stage
  def advance_stage
    next_stage = @lead.next_stage

    unless next_stage
      redirect_to admin_lead_path(@lead), alert: 'Lead is already at the final stage.'
      return
    end

    if @lead.update(current_stage: next_stage)
      redirect_to admin_lead_path(@lead), notice: "Lead advanced to #{next_stage.humanize} stage."
    else
      redirect_to admin_lead_path(@lead), alert: 'Failed to advance lead stage.'
    end
  end

  # PATCH /admin/leads/1/go_back_stage
  def go_back_stage
    unless @lead.can_go_back?
      redirect_to admin_lead_path(@lead), alert: 'Cannot go back from current stage.'
      return
    end

    previous_stage = @lead.previous_stage
    if @lead.update(current_stage: previous_stage)
      redirect_to admin_lead_path(@lead), notice: "Lead moved back to #{previous_stage.humanize} stage."
    else
      redirect_to admin_lead_path(@lead), alert: 'Failed to move lead back.'
    end
  end

  # PATCH /admin/leads/1/update_stage
  def update_stage
    new_stage = params[:new_stage]

    # Validate that the stage exists in our enum
    unless Lead.current_stages.key?(new_stage)
      redirect_to admin_lead_path(@lead), alert: 'Invalid stage.'
      return
    end

    # Check if the lead can transition to this stage
    unless @lead.next_stage_options.include?(new_stage)
      redirect_to admin_lead_path(@lead), alert: 'Cannot transition to this stage from current state.'
      return
    end

    # Prevent changes if lead is already converted
    if @lead.cannot_change_stage?
      redirect_to admin_lead_path(@lead), alert: 'Lead stage cannot be changed after conversion.'
      return
    end

    # Use the appropriate transition method based on the new stage
    success = case new_stage
    when 'consultation_scheduled'
      @lead.move_to_consultation_scheduled!
    when 'one_on_one'
      @lead.move_to_one_on_one!
    when 'follow_up'
      @lead.move_to_follow_up!
    when 'follow_up_successful'
      @lead.mark_follow_up_successful!
    when 'follow_up_unsuccessful'
      @lead.mark_follow_up_unsuccessful!
    when 'not_interested'
      @lead.mark_not_interested!
    when 're_follow_up'
      @lead.move_to_re_follow_up!
    when 'converted'
      # For conversion, we might need to create a customer first
      # For now, just mark as converted without customer_id
      @lead.update!(current_stage: 'converted', stage_updated_at: Time.current)
      true
    when 'lead_closed'
      @lead.close_lead!
    else
      false
    end

    if success
      stage_display = @lead.stage_display_name
      redirect_to admin_lead_path(@lead), notice: "✅ Lead successfully moved to: #{stage_display}"
    else
      redirect_to admin_lead_path(@lead), alert: "❌ Failed to update lead stage to #{new_stage.humanize}"
    end
  end

  # PATCH /admin/leads/1/convert_stage
  def convert_stage
    new_stage = params[:stage] || params[:new_stage]

    Rails.logger.info "convert_stage called with params: #{params.inspect}"
    Rails.logger.info "new_stage: #{new_stage}, current_stage: #{@lead.current_stage}"

    # Validate that the stage exists in our enum
    unless Lead.current_stages.key?(new_stage)
      Rails.logger.error "Invalid stage: #{new_stage}. Valid stages: #{Lead.current_stages.keys}"
      respond_to do |format|
        format.html { redirect_to admin_leads_path, alert: 'Invalid stage.' }
        format.json { render json: { success: false, message: 'Invalid stage.' } }
      end
      return
    end

    # Prevent changes if lead is already converted or closed
    if @lead.cannot_change_stage?
      respond_to do |format|
        format.html { redirect_to admin_leads_path, alert: 'Lead stage cannot be changed after conversion or closure.' }
        format.json { render json: { success: false, message: 'Lead stage cannot be changed after conversion or closure.' } }
      end
      return
    end

    # Use the appropriate transition method based on the new stage
    old_stage = @lead.current_stage
    success = case new_stage
    when 'lead_generated'
      @lead.update!(current_stage: 'lead_generated', stage_updated_at: Time.current)
      true
    when 'consultation_scheduled'
      result = @lead.move_to_consultation_scheduled!
      Rails.logger.info "Move to consultation_scheduled result: #{result}, new current_stage: #{@lead.reload.current_stage}"
      result
    when 'one_on_one'
      @lead.move_to_one_on_one!
    when 'follow_up'
      @lead.move_to_follow_up!
    when 'follow_up_successful'
      @lead.mark_follow_up_successful!
    when 'follow_up_unsuccessful'
      @lead.mark_follow_up_unsuccessful!
    when 'not_interested'
      @lead.mark_not_interested!
    when 're_follow_up'
      @lead.move_to_re_follow_up!
    when 'converted'
      # Instead of just updating the stage, redirect to customer conversion flow
      # This ensures that a customer is actually created when lead is marked as converted
      Rails.logger.info "Lead #{@lead.id} marked for conversion - redirecting to customer creation flow"

      # Don't update the stage here - let the customer creation process handle it
      # Set a flag to handle this special case in the response
      @redirect_to_conversion = true
      true
    when 'referral_settled'
      @lead.update!(current_stage: 'referral_settled', stage_updated_at: Time.current, transferred_amount: true)
      true
    when 'lead_closed'
      @lead.close_lead!
    else
      Rails.logger.error "Unknown stage: #{new_stage}"
      false
    end

    Rails.logger.info "Stage transition: #{old_stage} → #{new_stage}, success: #{success}"

    if success
      # Check if we need to redirect to customer conversion flow
      if @redirect_to_conversion
        respond_to do |format|
          format.html { redirect_to convert_to_customer_admin_lead_path(@lead), notice: "🔄 Lead ready for customer conversion. Please proceed to create the customer account." }
          format.json { render json: { success: true, redirect_to_conversion: true, redirect_url: convert_to_customer_admin_lead_path(@lead), message: "Lead ready for conversion - redirecting to customer creation" } }
        end
      else
        stage_display = @lead.stage_display_name
        respond_to do |format|
          format.html { redirect_to admin_leads_path, notice: "✅ Lead ##{@lead.lead_id} successfully converted to: #{stage_display}" }
          format.json { render json: { success: true, message: "Lead successfully converted to: #{stage_display}", new_stage: new_stage } }
        end
      end
    else
      respond_to do |format|
        format.html { redirect_to admin_leads_path, alert: "❌ Failed to convert lead stage to #{new_stage.humanize}" }
        format.json { render json: { success: false, message: "Failed to convert lead stage to #{new_stage.humanize}" } }
      end
    end
  rescue => e
    Rails.logger.error "Lead stage conversion failed for lead #{@lead.id}: #{e.message}"
    respond_to do |format|
      format.html { redirect_to admin_leads_path, alert: "❌ Error converting lead stage: #{e.message}" }
      format.json { render json: { success: false, message: "Error converting lead stage: #{e.message}" } }
    end
  end

  # GET /admin/leads/check_existing_customer
  def check_existing_customer
    contact_number = params[:contact_number]
    email = params[:email]

    existing_customers = []
    existing_leads = []

    # Check by contact number/mobile
    if contact_number.present?
      clean_contact = contact_number.gsub(/\D/, '')
      customer_by_mobile = Customer.where("mobile LIKE ?", "%#{clean_contact}%").first
      if customer_by_mobile
        existing_customers << {
          id: customer_by_mobile.id,
          name: customer_by_mobile.display_name,
          mobile: customer_by_mobile.mobile,
          email: customer_by_mobile.email,
          match_type: 'mobile'
        }
      end

      # Also check for existing leads with same contact number (get all, not just first)
      # First try exact match
      leads_by_mobile = Lead.where(contact_number: contact_number)

      # If no exact match and contact_number is longer than 3 digits, try partial match
      if leads_by_mobile.empty? && clean_contact.length > 3
        leads_by_mobile = Lead.where("contact_number LIKE ?", "%#{contact_number}%")
      end

      leads_by_mobile.each do |lead|
        # Determine if this is exact or partial match
        match_type = lead.contact_number == contact_number ? 'mobile_exact' : 'mobile_partial'

        existing_leads << {
          id: lead.id,
          lead_id: lead.lead_id,
          name: lead.display_name,
          contact_number: lead.contact_number,
          email: lead.email,
          product_category: lead.product_category,
          product_subcategory: lead.product_subcategory,
          current_stage: lead.current_stage,
          match_type: match_type
        }
      end
    end

    # Check by email
    if email.present?
      customer_by_email = Customer.where(email: email).first
      if customer_by_email && !existing_customers.any? { |c| c[:id] == customer_by_email.id }
        existing_customers << {
          id: customer_by_email.id,
          name: customer_by_email.display_name,
          mobile: customer_by_email.mobile,
          email: customer_by_email.email,
          match_type: 'email'
        }
      end

      # Also check for existing leads with same email (get all, not just first)
      leads_by_email = Lead.where(email: email)
      leads_by_email.each do |lead|
        # Avoid duplicates if already found by mobile
        next if existing_leads.any? { |l| l[:id] == lead.id }

        existing_leads << {
          id: lead.id,
          lead_id: lead.lead_id,
          name: lead.display_name,
          contact_number: lead.contact_number,
          email: lead.email,
          product_category: lead.product_category,
          product_subcategory: lead.product_subcategory,
          current_stage: lead.current_stage,
          match_type: 'email'
        }
      end
    end

    # For each found customer, also check if they have any existing leads
    existing_customers.each do |customer_data|
      customer_id = customer_data[:id]
      customer_mobile = customer_data[:mobile]
      customer_email = customer_data[:email]

      # Find leads for this customer by their mobile and email only
      customer_leads = []

      # Search by mobile (clean both numbers for comparison)
      if customer_mobile.present?
        clean_customer_mobile = customer_mobile.gsub(/\D/, '')
        customer_leads += Lead.where("REPLACE(REPLACE(contact_number, ' ', ''), '+', '') LIKE ?", "%#{clean_customer_mobile}%")
      end

      # Search by email
      if customer_email.present?
        customer_leads += Lead.where(email: customer_email)
      end

      # Remove duplicates and avoid duplicating leads already found by direct search
      customer_leads.uniq!
      customer_leads.each do |lead|
        next if existing_leads.any? { |l| l[:id] == lead.id }

        existing_leads << {
          id: lead.id,
          lead_id: lead.lead_id,
          name: lead.display_name,
          contact_number: lead.contact_number,
          email: lead.email,
          product_category: lead.product_category,
          product_subcategory: lead.product_subcategory,
          current_stage: lead.current_stage,
          match_type: 'customer_associated',
          associated_customer_id: customer_id,
          associated_customer_name: customer_name
        }
      end
    end

    render json: {
      exists: existing_customers.any?,
      customers: existing_customers,
      has_existing_leads: existing_leads.any?,
      leads: existing_leads
    }
  end

  # PATCH /admin/leads/bulk_update_stage
  def bulk_update_stage
    lead_ids = params[:lead_ids]
    new_stage = params[:stage]

    unless lead_ids.present? && Lead.current_stages.key?(new_stage)
      redirect_to admin_leads_path, alert: 'Invalid parameters for bulk update.'
      return
    end

    leads = Lead.where(id: lead_ids)
    updated_count = 0
    failed_count = 0

    leads.each do |lead|
      if lead.available_stages_for_transition.include?(new_stage)
        if lead.update(current_stage: new_stage, stage_updated_at: Time.current)
          updated_count += 1
        else
          failed_count += 1
        end
      else
        failed_count += 1
      end
    end

    if failed_count == 0
      redirect_to admin_leads_path, notice: "Successfully updated #{updated_count} leads to #{new_stage.humanize} stage."
    elsif updated_count > 0
      redirect_to admin_leads_path, notice: "Updated #{updated_count} leads. #{failed_count} leads could not be updated due to stage restrictions."
    else
      redirect_to admin_leads_path, alert: "No leads could be updated. Please check stage transition rules."
    end
  end

  # PATCH /admin/leads/1/mark_not_interested
  def mark_not_interested
    unless @lead.can_mark_not_interested?
      redirect_to admin_lead_path(@lead), alert: 'Lead cannot be marked as not interested at this stage.'
      return
    end

    if @lead.mark_not_interested!
      redirect_to admin_lead_path(@lead), notice: '🚫 Lead marked as Not Interested.'
    else
      redirect_to admin_lead_path(@lead), alert: 'Failed to mark lead as not interested.'
    end
  end

  # PATCH /admin/leads/1/close_lead
  def close_lead
    unless @lead.can_close_lead?
      redirect_to admin_lead_path(@lead), alert: 'Lead cannot be closed at this stage.'
      return
    end

    if @lead.close_lead!
      redirect_to admin_lead_path(@lead), notice: '📁 Lead successfully closed.'
    else
      redirect_to admin_lead_path(@lead), alert: 'Failed to close lead.'
    end
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

  # POST /admin/leads/branch_out
  def branch_out
    source_lead_id = params[:source_lead_id]
    source_lead = Lead.find_by(id: source_lead_id)

    unless source_lead
      redirect_to admin_leads_path, alert: 'Source lead not found.'
      return
    end

    # Create new lead by copying data from source lead but with different policy category/subcategory
    @lead = Lead.new(source_lead.attributes.except('id', 'lead_id', 'created_at', 'updated_at',
                                                   'stage_updated_at', 'converted_customer_id',
                                                   'policy_created_id', 'is_branch_out', 'parent_lead_id'))

    # Set default stage and date for the new lead
    @lead.current_stage = 'lead_generated'
    @lead.created_date = Date.current

    # Clear policy-specific fields so user can set new ones
    @lead.product_category = nil
    @lead.product_subcategory = nil
    @lead.notes = "Branched out from lead ID: #{source_lead.lead_id}\n\n" + (@lead.notes || '')

    # Set branch out flag and parent lead reference
    @lead.is_branch_out = true
    @lead.parent_lead_id = source_lead.id

    # IMPORTANT: Preserve affiliate and ambassador from source lead
    @lead.affiliate_id = source_lead.affiliate_id
    @lead.ambassador_id = source_lead.ambassador_id

    # Store source lead ID for reference
    session[:source_lead_id] = source_lead.id
    session[:branch_out_mode] = true

    render :new
  rescue => e
    Rails.logger.error "Branch out failed: #{e.message}"
    redirect_to admin_leads_path, alert: "Failed to branch out lead: #{e.message}"
  end

  # POST /admin/leads/branch_out_from_customer
  def branch_out_from_customer
    source_customer_id = params[:source_customer_id]
    source_customer = Customer.find_by(id: source_customer_id)

    unless source_customer
      redirect_to admin_leads_path, alert: 'Source customer not found.'
      return
    end

    # Create new lead using customer information
    @lead = Lead.new

    # Set customer information from the existing customer
    @lead.customer_type = source_customer.customer_type || 'individual'
    @lead.name = source_customer.display_name
    @lead.first_name = source_customer.first_name
    @lead.middle_name = source_customer.middle_name
    @lead.last_name = source_customer.last_name
    @lead.company_name = source_customer.company_name
    @lead.contact_number = source_customer.mobile
    @lead.email = source_customer.email
    @lead.birth_date = source_customer.birth_date
    @lead.gender = source_customer.gender
    @lead.marital_status = source_customer.marital_status
    @lead.pan_no = source_customer.pan_no
    @lead.birth_place = source_customer.birth_place
    @lead.height = source_customer.height
    @lead.weight = source_customer.weight
    @lead.education = source_customer.education
    @lead.business_job = source_customer.business_job
    @lead.business_name = source_customer.business_name
    @lead.job_name = source_customer.job_name
    @lead.occupation = source_customer.occupation
    @lead.type_of_duty = source_customer.type_of_duty
    @lead.annual_income = source_customer.annual_income
    @lead.address = source_customer.address
    @lead.state = source_customer.state
    @lead.city = source_customer.city
    @lead.gst_no = source_customer.gst_no

    # Set default stage and date for the new lead
    @lead.current_stage = 'lead_generated'
    @lead.created_date = Date.current
    @lead.lead_source = 'walk_in' # Default to walk_in for existing customers

    # Clear policy-specific fields so user can set new ones
    @lead.product_category = nil
    @lead.product_subcategory = nil
    @lead.notes = "Created from existing customer: #{source_customer.display_name} (ID: #{source_customer.id})"

    # Set as direct lead by default (can be changed by user)
    @lead.is_direct = true

    # Set branch out flag and customer reference
    @lead.is_branch_out = true
    @lead.converted_customer_id = source_customer.id

    # Store customer ID for reference
    session[:source_customer_id] = source_customer.id
    session[:branch_out_mode] = true

    render :new
  rescue => e
    Rails.logger.error "Branch out from customer failed: #{e.message}"
    redirect_to admin_leads_path, alert: "Failed to create lead from customer: #{e.message}"
  end

  # GET /admin/leads/download
  def download
    format_type = params[:format_type]

    scope = Lead.all
    scope = scope.where(current_stage: 'converted') if params[:tab] == 'converted'
    scope = scope.where.not(current_stage: 'converted') unless params[:tab] == 'converted'

    scope = scope.search_leads(params[:search]) if params[:search].present?
    scope = scope.by_stage(params[:current_stage]) if params[:current_stage].present?
    scope = scope.by_source(params[:lead_source]) if params[:lead_source].present?
    scope = scope.by_product_category(params[:product_category]) if params[:product_category].present?

    case format_type
    when 'csv_individual'
      data = scope.where(customer_type: 'individual').order(:created_at)
      send_data generate_leads_csv(data), filename: "individual_leads_#{Date.current}.csv", type: 'text/csv'
    when 'csv_corporate'
      data = scope.where(customer_type: 'corporate').order(:created_at)
      send_data generate_leads_csv(data), filename: "corporate_leads_#{Date.current}.csv", type: 'text/csv'
    when 'excel_individual'
      data = scope.where(customer_type: 'individual').order(:created_at)
      send_data generate_leads_excel(data),
                filename: "individual_leads_#{Date.current}.xlsx",
                type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    when 'excel_corporate'
      data = scope.where(customer_type: 'corporate').order(:created_at)
      send_data generate_leads_excel(data),
                filename: "corporate_leads_#{Date.current}.xlsx",
                type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    else
      redirect_to admin_leads_path, alert: 'Invalid download format.'
    end
  end

  private

  def generate_leads_csv(leads)
    require 'csv'
    CSV.generate(headers: true) do |csv|
      csv << %w[ID LeadID Name ContactNumber Email CustomerType FirstName LastName CompanyName
                Address City State Gender BirthDate PAN GST AnnualIncome ProductCategory
                ProductSubcategory LeadSource CurrentStage IsDirectLead Affiliate
                ReferralAmount CreatedAt]
      leads.find_each do |l|
        csv << [l.id, l.lead_id, l.name, l.contact_number, l.email,
                l.customer_type&.humanize, l.first_name, l.last_name, l.company_name,
                l.address, l.city, l.state, l.gender&.humanize, l.birth_date,
                l.pan_no, l.gst_no, l.annual_income,
                l.product_category&.humanize, l.product_subcategory,
                l.lead_source&.humanize, l.current_stage&.humanize,
                l.is_direct ? 'Direct' : 'Affiliate',
                l.affiliate&.full_name,
                l.referral_amount,
                l.created_at.strftime('%Y-%m-%d %H:%M:%S')]
      end
    end
  end

  def generate_leads_excel(leads)
    require 'caxlsx'
    package = Axlsx::Package.new
    wb = package.workbook
    hdr_style = wb.styles.add_style(bg_color: '1565C0', fg_color: 'FFFFFF', b: true,
                                     alignment: { horizontal: :center })
    row_style = wb.styles.add_style(alignment: { horizontal: :left })
    wb.add_worksheet(name: 'Leads') do |sheet|
      sheet.add_row %w[ID LeadID Name ContactNumber Email CustomerType FirstName LastName CompanyName
                       Address City State Gender BirthDate PAN GST AnnualIncome ProductCategory
                       ProductSubcategory LeadSource CurrentStage IsDirectLead Affiliate
                       ReferralAmount CreatedAt], style: hdr_style
      leads.find_each do |l|
        sheet.add_row [l.id, l.lead_id, l.name, l.contact_number, l.email,
                       l.customer_type&.humanize, l.first_name, l.last_name, l.company_name,
                       l.address, l.city, l.state, l.gender&.humanize, l.birth_date&.to_s,
                       l.pan_no, l.gst_no, l.annual_income&.to_f,
                       l.product_category&.humanize, l.product_subcategory,
                       l.lead_source&.humanize, l.current_stage&.humanize,
                       l.is_direct ? 'Direct' : 'Affiliate',
                       l.affiliate&.full_name,
                       l.referral_amount&.to_f,
                       l.created_at.strftime('%Y-%m-%d %H:%M:%S')], style: row_style
      end
    end
    package.to_stream.read
  end

  # JSON response helper method
  def json_response(object, status = :ok)
    render json: object, status: status
  end

  def set_lead
    @lead = Lead.find(params[:id])
  end

  def lead_params
    params.require(:lead).permit(
      :name, :contact_number, :email, :address, :city, :state,
      :referred_by, :product_category, :product_subcategory, :customer_type, :current_stage, :lead_source,
      :call_disposition, :referral_amount, :notes, :created_date,
      :note, :is_direct, :affiliate_id, :ambassador_id, :is_branch_out, :parent_lead_id,
      :first_name, :middle_name, :last_name, :birth_date, :gender, :pan_no, :gst_no,
      :company_name, :marital_status, :height, :weight, :birth_place,
      :education, :business_job, :business_name, :job_name, :occupation,
      :type_of_duty, :annual_income, :additional_information
    )
  end

  def extract_first_name(full_name)
    full_name.to_s.split(' ').first || 'Unknown'
  end

  def extract_last_name(full_name)
    names = full_name.to_s.split(' ')
    names.length > 1 ? names[1..-1].join(' ') : 'Unknown'
  end

  # Find existing customer for a lead based on parent/branch relationships
  def find_existing_customer_for_lead(lead)
    # First check if this lead is already converted
    return Customer.find_by(id: lead.converted_customer_id) if lead.converted_customer_id.present?

    # For branch out leads, check parent lead first
    if lead.is_branch_out? && lead.parent_lead_id.present?
      parent_lead = Lead.find_by(id: lead.parent_lead_id)
      if parent_lead&.converted_customer_id.present?
        return Customer.find_by(id: parent_lead.converted_customer_id)
      end

      # Check sibling branch leads
      sibling_leads = Lead.where(parent_lead_id: lead.parent_lead_id)
                         .where.not(id: lead.id)
                         .where.not(converted_customer_id: nil)
      if sibling_leads.any?
        return Customer.find_by(id: sibling_leads.first.converted_customer_id)
      end
    end

    # For parent leads, check if any branch leads are converted
    if !lead.is_branch_out?
      branch_leads = Lead.where(parent_lead_id: lead.id, is_branch_out: true)
                         .where.not(converted_customer_id: nil)
      if branch_leads.any?
        return Customer.find_by(id: branch_leads.first.converted_customer_id)
      end
    end

    # Check by mobile number or email
    existing_customer = nil
    if lead.contact_number.present?
      existing_customer = Customer.find_by(mobile: lead.contact_number)
    end

    if !existing_customer && lead.email.present?
      existing_customer = Customer.find_by(email: lead.email)
    end

    existing_customer
  end

  # Determine conversion context for display in the UI
  def determine_conversion_context(lead, existing_customer)
    return :no_customer unless existing_customer

    # Check the relationship between lead and existing customer
    if lead.is_branch_out? && lead.parent_lead_id.present?
      parent_lead = Lead.find_by(id: lead.parent_lead_id)
      if parent_lead&.converted_customer_id == existing_customer.id
        return :parent_customer
      end

      sibling_leads = Lead.where(parent_lead_id: lead.parent_lead_id)
                         .where.not(id: lead.id)
                         .where(converted_customer_id: existing_customer.id)
      return :sibling_customer if sibling_leads.any?
    end

    if !lead.is_branch_out?
      branch_leads = Lead.where(parent_lead_id: lead.id, is_branch_out: true)
                         .where(converted_customer_id: existing_customer.id)
      return :branch_customer if branch_leads.any?
    end

    # Customer exists by mobile/email match
    :contact_match
  end

  # Link a lead to an existing customer
  def link_lead_to_existing_customer(lead, customer)
    lead.update!(
      current_stage: 'converted',
      converted_customer_id: customer.id
    )

    # Add tracking notes
    case determine_conversion_context(lead, customer)
    when :parent_customer
      lead.update(notes: "#{lead.notes}\n\n[System] Branch lead linked to existing customer from parent lead.")
    when :sibling_customer
      lead.update(notes: "#{lead.notes}\n\n[System] Branch lead linked to existing customer from sibling lead.")
    when :branch_customer
      lead.update(notes: "#{lead.notes}\n\n[System] Parent lead linked to existing customer from branch lead.")
    when :contact_match
      lead.update(notes: "#{lead.notes}\n\n[System] Lead linked to existing customer by contact match.")
    end
  end

  # Map lead product_category + product_subcategory to ClientService service_type
  def client_service_type_for_lead(lead)
    return nil unless lead.product_subcategory.present?

    case lead.product_category
    when 'taxation'
      { 'itr' => 'taxation_itr', 'tax_planning' => 'taxation_tax_planning' }[lead.product_subcategory]
    when 'loans'
      { 'personal' => 'loans_personal', 'home' => 'loans_home', 'mortgage' => 'loans_mortgage', 'business' => 'loans_business' }[lead.product_subcategory]
    when 'travel'
      { 'domestic' => 'travel_domestic', 'international' => 'travel_international' }[lead.product_subcategory]
    when 'credit_card'
      { 'rewards' => 'credit_card_rewards', 'business' => 'credit_card_business', 'travel' => 'credit_card_travel' }[lead.product_subcategory]
    when 'investments'
      { 'mutual_fund' => 'investments_mutual_fund', 'fd' => 'investments_fd', 'other' => 'investments_other' }[lead.product_subcategory]
    end
  end

  # Redirect to appropriate creation page based on lead product info
  def redirect_to_insurance_creation(lead, customer)
    if lead.product_category == 'insurance' && lead.product_subcategory.present?
      case lead.product_subcategory
      when 'health'
        redirect_to new_admin_health_insurance_path(customer_id: customer.id, lead_id: lead.id),
                    notice: "Redirected to Health Insurance creation. Lead and customer details will be pre-filled."
      when 'life'
        redirect_to new_admin_life_insurance_path(customer_id: customer.id, lead_id: lead.id),
                    notice: "Redirected to Life Insurance creation. Lead and customer details will be pre-filled."
      when 'motor'
        redirect_to new_admin_motor_insurance_path(customer_id: customer.id, lead_id: lead.id),
                    notice: "Redirected to Motor Insurance creation. Lead and customer details will be pre-filled."
      when 'general', 'travel', 'other'
        redirect_to new_admin_other_insurance_path(customer_id: customer.id, lead_id: lead.id),
                    notice: "Redirected to Other Insurance creation. Lead and customer details will be pre-filled."
      else
        redirect_to admin_customer_path(customer),
                    notice: "Lead converted successfully. Please select insurance type manually."
      end
    else
      service_type = client_service_type_for_lead(lead)
      if service_type.present?
        redirect_to new_admin_client_service_path(service_type: service_type, customer_id: customer.id, lead_id: lead.id),
                    notice: "Lead converted successfully. Please fill in the #{ClientService::SERVICE_TYPES[service_type]} details."
      else
        redirect_to admin_customer_path(customer),
                    notice: "Lead converted successfully. Customer details available."
      end
    end
  end

  # Validate lead deletion based on specified scenarios
  def validate_lead_deletion(lead)
    # Scenario: Branch Lead B has a customer, User tries to delete Branch Lead B
    if lead.is_branch_out? && lead.converted_customer_id.present?
      return {
        can_delete: false,
        message: "Customer already created for this lead."
      }
    end

    # Scenario: Parent Lead A has a customer, User tries to delete Parent Lead A
    if !lead.is_branch_out? && lead.converted_customer_id.present?
      return {
        can_delete: false,
        message: "Customer already created for this lead."
      }
    end

    # Check for insurance policies directly linked to this lead
    lead_policy_count = 0
    begin
      lead_policy_count += HealthInsurance.where(lead_id: lead.lead_id).count rescue 0
      lead_policy_count += LifeInsurance.where(lead_id: lead.lead_id).count rescue 0
      lead_policy_count += MotorInsurance.where(lead_id: lead.lead_id).count rescue 0
      lead_policy_count += OtherInsurance.where(lead_id: lead.lead_id).count rescue 0 if defined?(OtherInsurance)
    rescue
      lead_policy_count = 0
    end

    if lead_policy_count > 0
      return {
        can_delete: false,
        message: "Cannot delete lead with #{lead_policy_count} linked insurance policy(ies). This would cause data integrity issues."
      }
    end

    # Scenario: Branch Lead B has a customer, User tries to delete Parent Lead A - ALLOWED
    # Scenario: Parent Lead A has a customer, Branch Lead B does not have a customer, User tries to delete Branch Lead B - ALLOWED

    return {
      can_delete: true,
      message: nil
    }
  end
end