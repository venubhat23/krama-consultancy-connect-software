namespace :payouts do
  desc 'Backfill missing payouts for all DrWise motor, life, health, and other insurance policies'
  task backfill_missing: :environment do
    puts "=" * 60
    puts "Backfilling missing payouts..."
    puts "=" * 60

    total_created = 0
    total_skipped = 0
    total_failed  = 0

    # ── Motor Insurance ──────────────────────────────────────────
    puts "\n[Motor Insurance]"

    motor_policies = MotorInsurance
      .where(is_admin_added: true, is_customer_added: false, is_agent_added: false)
      .where.not(id: Payout.where(policy_type: 'motor').select(:policy_id))
      .includes(:customer)

    puts "  Found #{motor_policies.count} motor policies missing payouts"

    motor_policies.each do |policy|
      unless policy.customer
        puts "  SKIP  motor ##{policy.id} — no customer"
        total_skipped += 1
        next
      end

      unless policy.net_premium.present? && policy.net_premium > 0
        puts "  SKIP  motor ##{policy.id} (#{policy.policy_number}) — net_premium blank/zero"
        total_skipped += 1
        next
      end

      begin
        # Older records may have product_through_dr = false/nil; force it in memory so the service doesn't skip them
        policy.product_through_dr = true if policy.respond_to?(:product_through_dr) && !policy.product_through_dr

        payout = StructuredPayoutService.create_for_policy(policy, 'motor')
        if payout
          cp_count = payout.commission_payouts.count
          puts "  OK    motor ##{policy.id} (#{policy.policy_number}) — payout ##{payout.id}, " \
               "total=#{payout.total_commission_amount}, commission_payouts=#{cp_count}"
          total_created += 1
        else
          puts "  SKIP  motor ##{policy.id} (#{policy.policy_number}) — service returned nil"
          total_skipped += 1
        end
      rescue => e
        puts "  FAIL  motor ##{policy.id} (#{policy.policy_number}) — #{e.message}"
        total_failed += 1
      end
    end

    # ── Life Insurance ───────────────────────────────────────────
    puts "\n[Life Insurance]"

    life_policies = LifeInsurance
      .where(is_admin_added: true, is_customer_added: false)
      .where.not(id: Payout.where(policy_type: 'life').select(:policy_id))
      .includes(:customer)

    puts "  Found #{life_policies.count} life policies missing payouts"

    life_policies.each do |policy|
      unless policy.customer
        puts "  SKIP  life ##{policy.id} — no customer"
        total_skipped += 1
        next
      end

      unless policy.net_premium.present? && policy.net_premium > 0
        puts "  SKIP  life ##{policy.id} (#{policy.policy_number}) — net_premium blank/zero"
        total_skipped += 1
        next
      end

      begin
        policy.product_through_dr = true if policy.respond_to?(:product_through_dr) && !policy.product_through_dr

        payout = StructuredPayoutService.create_for_policy(policy, 'life')
        if payout
          cp_count = payout.commission_payouts.count
          puts "  OK    life ##{policy.id} (#{policy.policy_number}) — payout ##{payout.id}, " \
               "total=#{payout.total_commission_amount}, commission_payouts=#{cp_count}"
          total_created += 1
        else
          puts "  SKIP  life ##{policy.id} (#{policy.policy_number}) — service returned nil"
          total_skipped += 1
        end
      rescue => e
        puts "  FAIL  life ##{policy.id} (#{policy.policy_number}) — #{e.message}"
        total_failed += 1
      end
    end

    # ── Health Insurance ─────────────────────────────────────────
    puts "\n[Health Insurance]"

    health_policies = HealthInsurance
      .where(is_admin_added: true, is_customer_added: false, is_agent_added: false)
      .where.not(id: Payout.where(policy_type: 'health').select(:policy_id))
      .includes(:customer)

    puts "  Found #{health_policies.count} health policies missing payouts"

    health_policies.each do |policy|
      unless policy.customer
        puts "  SKIP  health ##{policy.id} — no customer"
        total_skipped += 1
        next
      end

      unless policy.net_premium.present? && policy.net_premium > 0
        puts "  SKIP  health ##{policy.id} (#{policy.policy_number}) — net_premium blank/zero"
        total_skipped += 1
        next
      end

      begin
        policy.product_through_dr = true if policy.respond_to?(:product_through_dr) && !policy.product_through_dr

        payout = StructuredPayoutService.create_for_policy(policy, 'health')
        if payout
          cp_count = payout.commission_payouts.count
          puts "  OK    health ##{policy.id} (#{policy.policy_number}) — payout ##{payout.id}, " \
               "total=#{payout.total_commission_amount}, commission_payouts=#{cp_count}"
          total_created += 1
        else
          puts "  SKIP  health ##{policy.id} (#{policy.policy_number}) — service returned nil"
          total_skipped += 1
        end
      rescue => e
        puts "  FAIL  health ##{policy.id} (#{policy.policy_number}) — #{e.message}"
        total_failed += 1
      end
    end

    # ── Other Insurance ──────────────────────────────────────────
    puts "\n[Other Insurance]"

    other_policies = OtherInsurance
      .where(is_admin_added: true, is_customer_added: false, is_agent_added: false)
      .where.not(id: Payout.where(policy_type: 'other').select(:policy_id))
      .includes(:customer)

    puts "  Found #{other_policies.count} other policies missing payouts"

    other_policies.each do |policy|
      unless policy.customer
        puts "  SKIP  other ##{policy.id} — no customer"
        total_skipped += 1
        next
      end

      unless policy.net_premium.present? && policy.net_premium > 0
        puts "  SKIP  other ##{policy.id} (#{policy.policy_number}) — net_premium blank/zero"
        total_skipped += 1
        next
      end

      begin
        policy.product_through_dr = true if policy.respond_to?(:product_through_dr) && !policy.product_through_dr

        payout = StructuredPayoutService.create_for_policy(policy, 'other')
        if payout
          cp_count = payout.commission_payouts.count
          puts "  OK    other ##{policy.id} (#{policy.policy_number}) — payout ##{payout.id}, " \
               "total=#{payout.total_commission_amount}, commission_payouts=#{cp_count}"
          total_created += 1
        else
          puts "  SKIP  other ##{policy.id} (#{policy.policy_number}) — service returned nil"
          total_skipped += 1
        end
      rescue => e
        puts "  FAIL  other ##{policy.id} (#{policy.policy_number}) — #{e.message}"
        total_failed += 1
      end
    end

    # ── Summary ──────────────────────────────────────────────────
    puts "\n" + "=" * 60
    puts "Done. Created: #{total_created}  Skipped: #{total_skipped}  Failed: #{total_failed}"
    puts "=" * 60
  end
end
