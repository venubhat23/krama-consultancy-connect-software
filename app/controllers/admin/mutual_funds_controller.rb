class Admin::MutualFundsController < Admin::ApplicationController
  include ConfigurablePagination
  before_action :set_mutual_fund, only: [:show, :edit, :update, :destroy]

  def index
    @mutual_funds = MutualFund.includes(:customer, :sub_agent)

    @current_tab = params[:tab] || 'drwise'

    case @current_tab
    when 'drwise'
      @mutual_funds = @mutual_funds.where(is_admin_added: true, is_customer_added: false, is_agent_added: false)
    when 'non_drwise'
      @mutual_funds = @mutual_funds.where(
        '(is_customer_added = ? AND is_admin_added = ? AND is_agent_added = ?) OR (is_agent_added = ? AND is_customer_added = ? AND is_admin_added = ?)',
        true, false, false, true, false, false
      )
    end

    if params[:search].present?
      term = "%#{params[:search]}%"
      @mutual_funds = @mutual_funds.joins(:customer).where(
        'mutual_funds.fund_name ILIKE ? OR mutual_funds.folio_number ILIKE ? OR customers.first_name ILIKE ? OR customers.last_name ILIKE ? OR customers.company_name ILIKE ?',
        term, term, term, term, term
      )
    end

    if params[:investment_type].present?
      @mutual_funds = @mutual_funds.where(investment_type: params[:investment_type])
    end

    calculate_tab_statistics
    @mutual_funds = paginate_records(@mutual_funds.order(created_at: :desc))
  end

  def show
  end

  def new
    @mutual_fund = MutualFund.new
    set_form_data
    @mutual_fund.main_agent_commission_percentage = SystemSetting.default_main_agent_commission

    if params[:customer_id].present?
      @selected_customer = Customer.find_by(id: params[:customer_id])
      if @selected_customer
        @mutual_fund.customer_id = @selected_customer.id
        if @selected_customer.affiliate.present?
          @mutual_fund.sub_agent_id = @selected_customer.affiliate.id
          @auto_select_affiliate = @selected_customer.affiliate.id
        else
          @auto_select_affiliate = 'self'
        end
      end
    end
  end

  def edit
    set_form_data
    @selected_customer = @mutual_fund.customer if @mutual_fund.customer_id.present?
    @auto_select_affiliate = @mutual_fund.sub_agent_id.present? ? @mutual_fund.sub_agent_id : 'self'
  end

  def create
    @mutual_fund = MutualFund.new(mutual_fund_params)

    @mutual_fund.is_admin_added = true
    @mutual_fund.is_customer_added = false
    @mutual_fund.is_agent_added = false

    set_distributor_from_affiliate(@mutual_fund)

    if @mutual_fund.save
      redirect_to admin_mutual_funds_path, notice: 'Mutual fund was successfully created.'
    else
      set_form_data
      @auto_select_affiliate = @mutual_fund.sub_agent_id.present? ? @mutual_fund.sub_agent_id : 'self'
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @mutual_fund.assign_attributes(mutual_fund_params)
    set_distributor_from_affiliate(@mutual_fund)

    if @mutual_fund.save
      redirect_to admin_mutual_funds_path, notice: 'Mutual fund was successfully updated.'
    else
      set_form_data
      @auto_select_affiliate = @mutual_fund.sub_agent_id.present? ? @mutual_fund.sub_agent_id : 'self'
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @mutual_fund.delete_main_policy_from_r2 if @mutual_fund.has_main_policy_r2_document?
    @mutual_fund.policy_documents_records.each do |doc|
      R2Service.delete(doc.r2_file_key) if doc.r2_file_key.present?
    end
    @mutual_fund.destroy
    redirect_to admin_mutual_funds_path, notice: 'Mutual fund was successfully deleted.'
  end

  private

  def set_mutual_fund
    @mutual_fund = MutualFund.find(params[:id])
  end

  def set_form_data
    @customers = Customer.active.order(:first_name, :last_name, :company_name)
    @sub_agents = SubAgent.active.order(:first_name, :last_name)
    @distributors = Distributor.active.order(:first_name, :last_name)
    @investment_types = MutualFund::INVESTMENT_TYPES
  end

  def set_distributor_from_affiliate(record)
    return if record.sub_agent_id.blank?

    sub_agent = SubAgent.find_by(id: record.sub_agent_id)
    return unless sub_agent

    distributor_id = sub_agent.distributor_id || sub_agent.assigned_distributor&.id
    if distributor_id.present?
      record.distributor_id = distributor_id
    else
      default_distributor = Distributor.active.first
      record.distributor_id = default_distributor&.id
    end
  rescue StandardError => e
    Rails.logger.error "Failed to set distributor: #{e.message}"
  end

  def calculate_tab_statistics
    drwise = MutualFund.where(is_admin_added: true, is_customer_added: false, is_agent_added: false)
    non_drwise = MutualFund.where(
      '(is_customer_added = ? AND is_admin_added = ? AND is_agent_added = ?) OR (is_agent_added = ? AND is_customer_added = ? AND is_admin_added = ?)',
      true, false, false, true, false, false
    )

    @drwise_count = drwise.count
    @drwise_amount = drwise.sum(:amount) || 0
    @non_drwise_count = non_drwise.count
    @non_drwise_amount = non_drwise.sum(:amount) || 0
    @total_clients_count = MutualFund.joins(:customer).distinct.count('customers.id')
  end

  def mutual_fund_params
    params.require(:mutual_fund).permit(
      :customer_id, :sub_agent_id, :distributor_id,
      :investment_type, :amount, :fund_name, :folio_number, :plan_name,
      :start_date, :maturity_date,
      :main_agent_commission_percentage, :commission_amount, :tds_percentage, :tds_amount, :after_tds_value,
      :sub_agent_commission_percentage, :sub_agent_commission_amount, :sub_agent_tds_percentage, :sub_agent_tds_amount, :sub_agent_after_tds_value,
      :distributor_commission_percentage, :distributor_commission_amount, :distributor_tds_percentage, :distributor_tds_amount, :distributor_after_tds_value,
      :investor_commission_percentage, :investor_commission_amount,
      :company_expenses_percentage, :company_expenses_amount,
      :total_distribution_percentage, :profit_percentage, :profit_amount,
      :active
    )
  end
end
