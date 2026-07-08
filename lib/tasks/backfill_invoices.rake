namespace :invoices do
  desc "Backfill missing invoices for all paid affiliate, distributor, and ambassador payouts"
  task backfill: :environment do
    puts "=== Starting Invoice Backfill (#{Time.current}) ==="
    total_created = 0
    total_skipped = 0

    # -----------------------------------------------------------------------
    # 1. AFFILIATE invoices  (CommissionPayout payout_to:'affiliate')
    # -----------------------------------------------------------------------
    puts "\n--- Affiliate Invoices ---"
    affiliate_payouts = CommissionPayout.where(payout_to: 'affiliate', status: 'paid')
    puts "Found #{affiliate_payouts.count} paid affiliate commission payouts"

    groups = {}
    affiliate_payouts.each do |cp|
      policy = find_policy_for_cp(cp)
      next unless policy&.respond_to?(:sub_agent_id) && policy.sub_agent_id.present?

      month = (cp.payout_date || cp.updated_at.to_date).beginning_of_month
      key   = "#{policy.sub_agent_id}_#{month}"
      groups[key] ||= { sub_agent_id: policy.sub_agent_id, month: month, payouts: [] }
      groups[key][:payouts] << cp
    end

    groups.each_value do |data|
      created, skipped = create_affiliate_invoice(data[:sub_agent_id], data[:month], data[:payouts])
      total_created += created
      total_skipped += skipped
    end

    # -----------------------------------------------------------------------
    # 2. DISTRIBUTOR invoices  (DistributorPayout)
    # -----------------------------------------------------------------------
    puts "\n--- Distributor Invoices ---"
    dist_payouts = DistributorPayout.where(status: 'paid')
    puts "Found #{dist_payouts.count} paid distributor payouts"

    groups = {}
    dist_payouts.each do |dp|
      next unless dp.distributor_id.present?

      month = (dp.payout_date || dp.updated_at.to_date).beginning_of_month
      key   = "#{dp.distributor_id}_#{month}"
      groups[key] ||= { distributor_id: dp.distributor_id, month: month, payouts: [] }
      groups[key][:payouts] << dp
    end

    groups.each_value do |data|
      created, skipped = create_distributor_invoice(data[:distributor_id], data[:month], data[:payouts])
      total_created += created
      total_skipped += skipped
    end

    # -----------------------------------------------------------------------
    # 3. AMBASSADOR invoices  (CommissionPayout payout_to:'ambassador')
    # -----------------------------------------------------------------------
    puts "\n--- Ambassador Invoices ---"
    amb_payouts = CommissionPayout.where(payout_to: 'ambassador', status: 'paid')
    puts "Found #{amb_payouts.count} paid ambassador commission payouts"

    groups = {}
    amb_payouts.each do |cp|
      policy = find_policy_for_cp(cp)
      next unless policy&.respond_to?(:distributor_id) && policy.distributor_id.present?

      month = (cp.payout_date || cp.updated_at.to_date).beginning_of_month
      key   = "#{policy.distributor_id}_#{month}"
      groups[key] ||= { distributor_id: policy.distributor_id, month: month, payouts: [] }
      groups[key][:payouts] << cp
    end

    groups.each_value do |data|
      created, skipped = create_ambassador_invoice(data[:distributor_id], data[:month], data[:payouts])
      total_created += created
      total_skipped += skipped
    end

    puts "\n=== Backfill Complete: #{total_created} created, #{total_skipped} already existed ==="
  end

  # ---------------------------------------------------------------------------
  private

  def find_policy_for_cp(cp)
    case cp.policy_type
    when 'health' then HealthInsurance.find_by(id: cp.policy_id)
    when 'life'   then LifeInsurance.find_by(id: cp.policy_id)
    when 'motor'  then MotorInsurance.find_by(id: cp.policy_id)
    when 'other'  then OtherInsurance.find_by(id: cp.policy_id)
    end
  rescue StandardError
    nil
  end

  def invoice_number_for(prefix, entity_id, month)
    year_month  = month.strftime('%Y%m')
    base        = "INV-#{prefix}-#{year_month}-#{entity_id.to_s.rjust(5, '0')}"
    counter     = 1
    number      = base
    number      = "#{base}-#{counter += 1}" while Invoice.exists?(invoice_number: number)
    number
  end

  def create_affiliate_invoice(sub_agent_id, month, payouts)
    sub_agent = SubAgent.find_by(id: sub_agent_id)
    unless sub_agent
      puts "  SKIP affiliate #{sub_agent_id} — SubAgent not found"
      return [0, 0]
    end

    existing = Invoice.where(payout_type: 'affiliate', payout_id: sub_agent_id,
                             invoice_date: month.beginning_of_month..month.end_of_month).first
    if existing
      puts "  EXISTS affiliate #{sub_agent_id} (#{sub_agent.first_name} #{sub_agent.last_name}) #{month.strftime('%b %Y')} — #{existing.invoice_number}"
      return [0, 1]
    end

    total = payouts.sum(&:payout_amount).to_f
    return [0, 0] if total <= 0

    Invoice.create!(
      invoice_number:  invoice_number_for('AFF', sub_agent_id, month),
      payout_type:     'affiliate',
      payout_id:       sub_agent_id,
      total_amount:    total,
      status:          'paid',
      invoice_date:    month,
      due_date:        month,
      paid_at:         Time.current,
      recipient_name:  "#{sub_agent.first_name} #{sub_agent.last_name}",
      recipient_email: sub_agent.email,
      notes:           "Backfilled affiliate commission for #{payouts.count} policies in #{month.strftime('%B %Y')}"
    )
    puts "  CREATED affiliate #{sub_agent_id} (#{sub_agent.first_name} #{sub_agent.last_name}) #{month.strftime('%b %Y')} — ₹#{total}"
    [1, 0]
  rescue => e
    puts "  ERROR affiliate #{sub_agent_id}: #{e.message}"
    [0, 0]
  end

  def create_distributor_invoice(distributor_id, month, payouts)
    distributor = Distributor.find_by(id: distributor_id)
    unless distributor
      puts "  SKIP distributor #{distributor_id} — Distributor not found"
      return [0, 0]
    end

    existing = Invoice.where(payout_type: 'distributor', payout_id: distributor_id,
                             invoice_date: month.beginning_of_month..month.end_of_month).first
    if existing
      puts "  EXISTS distributor #{distributor_id} (#{distributor.display_name}) #{month.strftime('%b %Y')} — #{existing.invoice_number}"
      return [0, 1]
    end

    total = payouts.sum(&:payout_amount).to_f
    return [0, 0] if total <= 0

    Invoice.create!(
      invoice_number:  invoice_number_for('DIST', distributor_id, month),
      payout_type:     'distributor',
      payout_id:       distributor_id,
      total_amount:    total,
      status:          'paid',
      invoice_date:    month,
      due_date:        month,
      paid_at:         Time.current,
      recipient_name:  distributor.display_name,
      recipient_email: distributor.email || 'no-email@example.com',
      notes:           "Backfilled distributor commission for #{payouts.count} payouts in #{month.strftime('%B %Y')}"
    )
    puts "  CREATED distributor #{distributor_id} (#{distributor.display_name}) #{month.strftime('%b %Y')} — ₹#{total}"
    [1, 0]
  rescue => e
    puts "  ERROR distributor #{distributor_id}: #{e.message}"
    [0, 0]
  end

  def create_ambassador_invoice(distributor_id, month, payouts)
    distributor = Distributor.find_by(id: distributor_id)
    unless distributor
      puts "  SKIP ambassador/distributor #{distributor_id} — Distributor not found"
      return [0, 0]
    end

    existing = Invoice.where(payout_type: 'ambassador', payout_id: distributor_id,
                             invoice_date: month.beginning_of_month..month.end_of_month).first
    if existing
      puts "  EXISTS ambassador #{distributor_id} (#{distributor.display_name}) #{month.strftime('%b %Y')} — #{existing.invoice_number}"
      return [0, 1]
    end

    total = payouts.sum(&:payout_amount).to_f
    return [0, 0] if total <= 0

    Invoice.create!(
      invoice_number:  invoice_number_for('AMB', distributor_id, month),
      payout_type:     'ambassador',
      payout_id:       distributor_id,
      total_amount:    total,
      status:          'paid',
      invoice_date:    month,
      due_date:        month,
      paid_at:         Time.current,
      recipient_name:  distributor.display_name,
      recipient_email: distributor.email || 'no-email@example.com',
      notes:           "Backfilled ambassador commission for #{payouts.count} payouts in #{month.strftime('%B %Y')}"
    )
    puts "  CREATED ambassador #{distributor_id} (#{distributor.display_name}) #{month.strftime('%b %Y')} — ₹#{total}"
    [1, 0]
  rescue => e
    puts "  ERROR ambassador #{distributor_id}: #{e.message}"
    [0, 0]
  end
end
