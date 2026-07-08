class Admin::InvoicesController < ApplicationController
  before_action :set_invoice, only: [:show, :show_premium, :download_pdf, :download_premium_pdf, :mark_as_paid, :line_items]

  def index
    @invoices = Invoice.order(created_at: :desc)
                      .page(params[:page])
                      .per(20)

    # Filter by status
    if params[:status].present?
      @invoices = @invoices.where(status: params[:status])
    end

    # Filter by payout type
    if params[:payout_type].present?
      @invoices = @invoices.where(payout_type: params[:payout_type])
    end
  end

  def show
    @payout_record = @invoice.payout_record
  end

  def show_premium
    @payout_record = @invoice.payout_record
    render layout: false
  end

  def generate_invoice
    payout_type = params[:payout_type]
    payout_id = params[:payout_id]

    case payout_type
    when 'affiliate'
      payout = CommissionPayout.find_by(id: payout_id, payout_to: 'affiliate')
    when 'distributor'
      payout = DistributorPayout.find(payout_id)
    when 'ambassador'
      payout = CommissionPayout.find_by(id: payout_id, payout_to: 'ambassador')
    when 'commission'
      payout = Payout.find(payout_id)
    else
      render json: { error: 'Invalid payout type' }, status: 400
      return
    end

    unless payout
      render json: { error: 'Payout record not found' }, status: 404
      return
    end

    # Check if invoice already exists for this payout
    existing_invoice = Invoice.find_by(payout_type: payout_type, payout_id: payout_id)
    if existing_invoice
      render json: { error: 'Invoice already exists for this payout' }, status: 422
      return
    end

    # Generate invoice
    invoice = Invoice.create!(
      invoice_number: generate_invoice_number,
      payout_type: payout_type,
      payout_id: payout_id,
      total_amount: calculate_total_amount(payout),
      status: 'pending',
      invoice_date: Date.current,
      due_date: Date.current + 30.days
    )

    # Mark the payout as invoiced
    payout.update!(invoiced: true) if payout.respond_to?(:invoiced)

    render json: {
      success: true,
      message: 'Invoice generated successfully',
      invoice_id: invoice.id,
      invoice_number: invoice.invoice_number
    }
  rescue => e
    render json: { error: e.message }, status: 500
  end

  def line_items
    saved_items = @invoice.invoice_items.order(created_at: :desc)

    if saved_items.any?
      items_data = saved_items.limit(5).map do |item|
        {
          description: item.description,
          payout_type: item.payout_type&.humanize,
          qty:  '1 Policy',
          rate: format_inr(item.amount),
          amount: format_inr(item.amount)
        }
      end
      total_count  = saved_items.count
      total_amount = @invoice.formatted_amount
    else
      # Dynamically compute line items from CommissionPayout records
      commission_payouts = fetch_commission_payouts_for_invoice(@invoice)
      items_data = commission_payouts.first(5).map do |cp|
        policy = find_policy_for_payout(cp)
        {
          description: "#{@invoice.payout_type.humanize} Commission — #{policy&.policy_number || "Policy ##{cp.policy_id}"} (#{cp.policy_type.humanize})",
          payout_type: @invoice.payout_type.humanize,
          qty:  '1 Policy',
          rate: format_inr(cp.payout_amount),
          amount: format_inr(cp.payout_amount)
        }
      end
      total_count  = commission_payouts.size
      computed_total = commission_payouts.sum(&:payout_amount).to_f.round(2)
      # Sync total_amount if it has drifted
      @invoice.update_column(:total_amount, computed_total) if computed_total > 0 && computed_total != @invoice.total_amount.to_f.round(2)
      total_amount = "₹#{computed_total.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    end

    render json: {
      invoice_number: @invoice.invoice_number,
      total_amount:   total_amount,
      status:         @invoice.status,
      invoice_date:   @invoice.invoice_date.strftime('%d %b %Y'),
      total_line_items: total_count,
      items: items_data
    }
  end

  def mark_as_paid
    @invoice.update!(
      status: 'paid',
      paid_at: Time.current
    )

    # Update the associated payout record
    payout = @invoice.payout_record
    if payout.respond_to?(:mark_as_paid!)
      payout.mark_as_paid!
    else
      payout.update!(status: 'paid', paid_at: Time.current)
    end

    redirect_to admin_invoices_path, notice: 'Invoice marked as paid successfully'
  rescue => e
    redirect_to admin_invoices_path, alert: "Error marking invoice as paid: #{e.message}"
  end

  def download_pdf
    respond_to do |format|
      format.pdf do
        render pdf: "invoice_#{@invoice.invoice_number}",
               template: 'admin/invoices/show',
               layout: false,
               page_size: 'A4',
               margin: { top: 5, bottom: 5, left: 5, right: 5 },
               encoding: 'UTF-8'
      end
    end
  rescue => e
    redirect_to admin_invoices_path, alert: "Error generating PDF: #{e.message}"
  end

  def download_premium_pdf
    respond_to do |format|
      format.pdf do
        render pdf: "premium_invoice_#{@invoice.invoice_number}",
               template: 'admin/invoices/show_premium',
               layout: false,
               page_size: 'A4',
               margin: { top: 10, bottom: 10, left: 10, right: 10 },
               encoding: 'UTF-8',
               javascript_delay: 1000
      end
    end
  rescue => e
    redirect_to admin_invoices_path, alert: "Error generating premium PDF: #{e.message}"
  end

  private

  def format_inr(amount)
    "₹#{amount.to_f.round(2).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  end

  def find_policy_for_payout(cp)
    case cp.policy_type
    when 'health' then HealthInsurance.find_by(id: cp.policy_id)
    when 'life'   then LifeInsurance.find_by(id: cp.policy_id)
    when 'motor'  then MotorInsurance.find_by(id: cp.policy_id)
    when 'other'  then OtherInsurance.find_by(id: cp.policy_id)
    end
  end

  def fetch_commission_payouts_for_invoice(invoice)
    case invoice.payout_type
    when 'affiliate'
      sub_agent = SubAgent.find_by(id: invoice.payout_id)
      return [] unless sub_agent
      [HealthInsurance, LifeInsurance, MotorInsurance, OtherInsurance].flat_map do |klass|
        ptype = klass.name.underscore.gsub('_insurance', '')
        klass.where(sub_agent_id: sub_agent.id).flat_map do |pol|
          CommissionPayout.where(policy_type: ptype, policy_id: pol.id, payout_to: 'affiliate', status: 'paid')
        end
      end.sort_by { |cp| [cp.policy_type, cp.policy_id] }

    when 'distributor', 'ambassador'
      distributor = Distributor.find_by(id: invoice.payout_id)
      return [] unless distributor
      DistributorPayout.where(distributor_id: distributor.id, status: 'paid')
                       .order(created_at: :desc)

    when 'commission'
      payout = Payout.find_by(id: invoice.payout_id)
      payout ? [payout] : []
    else
      []
    end
  end

  def set_invoice
    @invoice = Invoice.find(params[:id])
  end

  def generate_invoice_number
    "INV-#{Date.current.strftime('%Y%m%d')}-#{rand(10000..99999)}"
  end

  def calculate_total_amount(payout)
    case payout.class.name
    when 'CommissionPayout'
      payout.payout_amount || 0
    when 'DistributorPayout'
      payout.payout_amount || 0
    when 'Payout'
      payout.total_commission_amount || payout.total_amount || 0
    else
      0
    end
  end
end