# =============================================================================
# CLEANUP BULK SEED DATA
# Run: rails runner cleanup_bulk_seed.rb  OR paste into rails console
# =============================================================================

SEED_MARKER = "BULK_SEED_TEST"

puts "=" * 60
puts "CLEANUP SEED DATA — #{Time.current}"
puts "=" * 60

seed_customer_ids = Customer.where("additional_information LIKE ?", "%#{SEED_MARKER}%").pluck(:id)
puts "Found #{seed_customer_ids.size} seed customers"

if seed_customer_ids.empty?
  puts "Nothing to clean up."
  exit
end

ActiveRecord::Base.transaction do

  # ── Health Insurance ──────────────────────────────────────────────────────
  hi_ids = HealthInsurance.where(customer_id: seed_customer_ids).pluck(:id)
  if hi_ids.any?
    HealthInsuranceMember.where(health_insurance_id: hi_ids).delete_all
    HealthInsuranceNominee.where(health_insurance_id: hi_ids).delete_all
    HealthInsuranceDocument.where(health_insurance_id: hi_ids).delete_all
    PolicyDocument.where(policy_type: "health", policy_id: hi_ids).delete_all
    CommissionPayout.where(policy_type: "health", policy_id: hi_ids).delete_all
    # Delete renewals first (FK: original_policy_id references health_insurances.id)
    HealthInsurance.where(original_policy_id: hi_ids).delete_all
    n = HealthInsurance.where(id: hi_ids).delete_all
    puts "  Deleted #{n} health policies (+ dependents)"
  end

  # ── Life Insurance ────────────────────────────────────────────────────────
  li_ids = LifeInsurance.where(customer_id: seed_customer_ids).pluck(:id)
  if li_ids.any?
    PolicyDocument.where(policy_type: "life", policy_id: li_ids).delete_all
    CommissionPayout.where(policy_type: "life", policy_id: li_ids).delete_all
    LifeInsurance.where(original_policy_id: li_ids).delete_all
    n = LifeInsurance.where(id: li_ids).delete_all
    puts "  Deleted #{n} life policies (+ dependents)"
  end

  # ── Motor Insurance ───────────────────────────────────────────────────────
  mi_ids = MotorInsurance.where(customer_id: seed_customer_ids).pluck(:id)
  if mi_ids.any?
    PolicyDocument.where(policy_type: "motor", policy_id: mi_ids).delete_all
    CommissionPayout.where(policy_type: "motor", policy_id: mi_ids).delete_all
    MotorInsurance.where(original_policy_id: mi_ids).delete_all
    n = MotorInsurance.where(id: mi_ids).delete_all
    puts "  Deleted #{n} motor policies (+ dependents)"
  end

  # ── Other Insurance ───────────────────────────────────────────────────────
  oi_ids = OtherInsurance.where(customer_id: seed_customer_ids).pluck(:id)
  if oi_ids.any?
    PolicyDocument.where(policy_type: "other", policy_id: oi_ids).delete_all
    CommissionPayout.where(policy_type: "other", policy_id: oi_ids).delete_all
    n = OtherInsurance.where(id: oi_ids).delete_all
    puts "  Deleted #{n} other policies (+ dependents)"
  end

  # ── Leads ─────────────────────────────────────────────────────────────────
  n = Lead.where("notes LIKE ?", "%#{SEED_MARKER}%").delete_all
  puts "  Deleted #{n} leads"

  # ── Customers ─────────────────────────────────────────────────────────────
  n = Customer.where(id: seed_customer_ids).delete_all
  puts "  Deleted #{n} customers"

  # ── Banners ───────────────────────────────────────────────────────────────
  n = Banner.where("description LIKE ?", "%#{SEED_MARKER}%").delete_all
  puts "  Deleted #{n} banners"

  # ── Agency Codes ──────────────────────────────────────────────────────────
  seed_codes = %w[STAR-H-001 NBUPA-H-002 CARE-H-003 LIC-L-001 SBIL-L-002
                  HDFC-L-003 MAX-L-004 HDFC-MO-001 BAJA-MO-002 TATA-MO-003
                  DIGI-MO-004 NATL-MO-005]
  n = AgencyCode.where(code: seed_codes).delete_all
  puts "  Deleted #{n} agency codes"

  # ── Brokers ───────────────────────────────────────────────────────────────
  broker_names = ["PolicyBazaar Broking", "Coverfox Insurance", "SecureNow Brokers",
                  "Ditto Insurance", "ACKO Broking Partners"]
  n = Broker.where(name: broker_names).delete_all
  puts "  Deleted #{n} brokers"

end

puts ""
puts "=" * 60
puts "CLEANUP COMPLETE"
puts "=" * 60
