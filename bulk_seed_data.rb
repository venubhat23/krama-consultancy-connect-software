# =============================================================================
# BULK SEED DATA SCRIPT
# Run: rails runner bulk_seed_data.rb
#      OR paste into rails console
#
# Creates:
#   5 Brokers | 12 AgencyCodes
#   500 Customers | 200 Leads
#   1600 Health | 1600 Life | 600 Motor | 200 Other Insurance
#   ~10% renewals per type | 5 Banners
# =============================================================================

SEED_MARKER = "BULK_SEED_TEST"
puts "=" * 60
puts "BULK SEED DATA — #{Time.current}"
puts "=" * 60

# ─── helpers ──────────────────────────────────────────────────────────────────

$phone_counter = Customer.maximum("CAST(SUBSTRING(mobile FROM 2) AS BIGINT)").to_i rescue 700_000_000
def next_mobile
  $phone_counter += 1
  "9#{$phone_counter.to_s.rjust(9, '0')}"
end

$email_counter = 0
def next_email(name)
  $email_counter += 1
  "#{name.downcase.gsub(/\s+/, '.')}.seed#{$email_counter}@testmail.in"
end

def rand_pan
  l = ('A'..'Z').to_a
  "#{l.sample(5).join}#{rand(1000..9999)}#{l.sample}"
end

def rand_gst
  l = ('A'..'Z').to_a
  state = rand(11..37).to_s.rjust(2, '0')
  "#{state}#{l.sample(5).join}#{rand(1000..9999)}#{l.sample}#{rand(1..9)}Z#{l.sample}"
end

$policy_seq = (MotorInsurance.maximum(:policy_number)&.scan(/\d+/)&.last.to_i + 1) rescue 100001
def next_policy_num(prefix)
  $policy_seq += 1
  "#{prefix}#{$policy_seq.to_s.rjust(8, '0')}"
end

def calc_premium(net, gst_pct)
  (net + net * gst_pct / 100.0).round(2)
end

FIRST_NAMES = %w[Aarav Aditya Akash Amit Ananya Arjun Aryan Deepak Divya Gaurav
                 Ishaan Karan Kavya Manoj Meera Mohit Nandini Neha Nikhil Pallavi
                 Pooja Priya Rahul Rajesh Rakesh Rohit Sachin Sanjeev Shweta Siddharth
                 Sneha Suresh Tanvi Tushar Uday Varun Vikash Vinod Vishal Yash].freeze

LAST_NAMES  = %w[Agarwal Bhat Chandra Desai Gupta Iyer Jain Joshi Kapoor Khanna
                 Kumar Malhotra Mehta Mishra Nair Patel Pillai Rao Reddy Shah
                 Sharma Shukla Singh Sinha Srivastava Tiwari Trivedi Varma Verma Yadav].freeze

STATES_CITIES = {
  "Maharashtra" => %w[Mumbai Pune Nagpur Nashik Aurangabad],
  "Karnataka"   => %w[Bangalore Mysore Hubli Mangalore Belgaum],
  "Tamil Nadu"  => %w[Chennai Coimbatore Madurai Salem Tiruchirappalli],
  "Delhi"       => %w[New\ Delhi Dwarka Rohini Janakpuri Laxmi\ Nagar],
  "Gujarat"     => %w[Ahmedabad Surat Vadodara Rajkot Gandhinagar],
  "Rajasthan"   => %w[Jaipur Jodhpur Udaipur Kota Ajmer],
  "Uttar Pradesh" => %w[Lucknow Kanpur Varanasi Agra Noida]
}.freeze

HEALTH_COMPANIES = [
  "Star Health Allied Insurance Co Ltd",
  "Niva Bupa Health Insurance Co Ltd",
  "Care Health Insurance Ltd",
  "Aditya Birla Health Insurance Co Ltd",
  "Manipal Cigna Health Insurance Company Limited",
  "HDFC ERGO General Insurance Co Ltd",
  "ICICI Lombard General Insurance Co Ltd"
].freeze

# Fetch life company names from DB (validated against InsuranceCompany table)
_life_db = InsuranceCompany.life_insurance.pluck(:name)
LIFE_COMPANIES = _life_db.presence || [
  "LIC India",
  "SBI Life Insurance Co Ltd",
  "HDFC Standard Life Insurance Co Ltd",
  "ICICI Prudential Life Insurance Co Ltd",
  "Max Life Insurance Co Ltd",
  "Bajaj Allianz Life Insurance Co Ltd",
  "Tata AIA Life Insurance Co Ltd"
].freeze

MOTOR_COMPANIES = [
  "HDFC ERGO General Insurance Co Ltd",
  "Bajaj Allianz General Insurance Company Limited",
  "Tata AIG General Insurance Co Ltd",
  "Go Digit General Insurance",
  "Reliance General Insurance Co Ltd",
  "IFFCO TOKIO General Insurance Co Ltd"
].freeze

OTHER_COMPANIES = [
  "HDFC ERGO General Insurance Co Ltd",
  "Bajaj Allianz General Insurance Company Limited",
  "Tata AIG General Insurance Co Ltd",
  "National Insurance Co Ltd",
  "United India Insurance Company Limited",
  "The New India Assurance Co Ltd"
].freeze

PAYMENT_MODES_HEALTH  = ["Yearly", "Half Yearly", "Quarterly", "Monthly", "Single"].freeze
PAYMENT_MODES_LIFE    = ["Yearly", "Half-Yearly", "Quarterly", "Monthly", "Single"].freeze
PAYMENT_MODES_MOTOR   = ["Yearly", "Half Yearly", "Quarterly", "Monthly"].freeze
PAYMENT_MODES_OTHER   = ["Yearly", "Half Yearly", "Quarterly", "Monthly"].freeze

HEALTH_INSURANCE_TYPES = ["Individual", "Family Floater", "Group"].freeze
MOTOR_CLASS_OF_VEHICLE = ["Private Car", "Two Wheeler", "Goods Vehicle"].freeze
MOTOR_INSURANCE_TYPES  = ["Comprehensive", "Third Party", "Own Damage"].freeze
MOTOR_VEHICLE_TYPES    = ["New Vehicle", "Old Vehicle"].freeze
OTHER_INSURANCE_TYPES  = ["Travel Insurance", "Property Insurance", "Cyber Insurance",
                           "Professional Indemnity", "Marine Insurance", "Other"].freeze

SUM_INSURED_OPTIONS = [
  500_000, 1_000_000, 1_500_000, 2_000_000, 3_000_000,
  5_000_000, 7_500_000, 10_000_000
].freeze

distributor_ids = Distributor.pluck(:id)
raise "No distributors found! Create at least one distributor first." if distributor_ids.empty?

sub_agent_ids = SubAgent.pluck(:id)

# ─── 1. BROKERS ───────────────────────────────────────────────────────────────

puts "\n[1/9] Creating Brokers..."
broker_names = ["PolicyBazaar Broking", "Coverfox Insurance", "SecureNow Brokers",
                "Ditto Insurance", "ACKO Broking Partners"]
seed_brokers = []
broker_names.each do |name|
  b = Broker.find_or_initialize_by(name: name)
  b.status = "active"
  b.notes  = SEED_MARKER if b.respond_to?(:notes)
  b.save!
  seed_brokers << b
end
puts "  ✓ #{seed_brokers.size} brokers ready"

# ─── 2. AGENCY CODES ──────────────────────────────────────────────────────────

puts "\n[2/9] Creating Agency Codes..."
agency_data = [
  { insurance_type: "Health Insurance", company_name: "Star Health Allied Insurance Co Ltd",
    agent_name: "Suresh Mehta", code: "STAR-H-001" },
  { insurance_type: "Health Insurance", company_name: "Niva Bupa Health Insurance Co Ltd",
    agent_name: "Anita Sharma", code: "NBUPA-H-002" },
  { insurance_type: "Health Insurance", company_name: "Care Health Insurance Ltd",
    agent_name: "Ravi Kumar", code: "CARE-H-003" },
  { insurance_type: "Life Insurance", company_name: "LIC India",
    agent_name: "Pradeep Gupta", code: "LIC-L-001" },
  { insurance_type: "Life Insurance", company_name: "SBI Life Insurance Co Ltd",
    agent_name: "Meena Patel", code: "SBIL-L-002" },
  { insurance_type: "Life Insurance", company_name: "HDFC Standard Life Insurance Co Ltd",
    agent_name: "Vijay Verma", code: "HDFC-L-003" },
  { insurance_type: "Life Insurance", company_name: "Max Life Insurance Co Ltd",
    agent_name: "Sonal Jain", code: "MAX-L-004" },
  { insurance_type: "Motor and Other Insurance", company_name: "HDFC ERGO General Insurance Co Ltd",
    agent_name: "Kiran Reddy", code: "HDFC-MO-001" },
  { insurance_type: "Motor and Other Insurance", company_name: "Bajaj Allianz General Insurance Company Limited",
    agent_name: "Mohan Das", code: "BAJA-MO-002" },
  { insurance_type: "Motor and Other Insurance", company_name: "Tata AIG General Insurance Co Ltd",
    agent_name: "Sunita Singh", code: "TATA-MO-003" },
  { insurance_type: "Motor and Other Insurance", company_name: "Go Digit General Insurance",
    agent_name: "Amit Tiwari", code: "DIGI-MO-004" },
  { insurance_type: "Motor and Other Insurance", company_name: "National Insurance Co Ltd",
    agent_name: "Deepa Nair", code: "NATL-MO-005" },
]
seed_agency_codes = []
agency_data.each do |data|
  ac = AgencyCode.find_or_initialize_by(code: data[:code])
  ac.assign_attributes(data)
  ac.save!
  seed_agency_codes << ac
end
puts "  ✓ #{seed_agency_codes.size} agency codes ready"

health_agency_codes = seed_agency_codes.select { |a| a.insurance_type == "Health Insurance" }
life_agency_codes   = seed_agency_codes.select { |a| a.insurance_type == "Life Insurance" }
motor_agency_codes  = seed_agency_codes.select { |a| a.insurance_type == "Motor and Other Insurance" }

# ─── 3. CUSTOMERS (500) ───────────────────────────────────────────────────────

puts "\n[3/9] Creating 500 Customers..."
seed_customers = []
corporate_count = 50  # 10% corporate

500.times do |i|
  state, cities = STATES_CITIES.to_a.sample
  city          = cities.sample
  is_corporate  = i < corporate_count

  if is_corporate
    company_name = "#{LAST_NAMES.sample} #{['Enterprises', 'Solutions', 'Industries', 'Group', 'Pvt Ltd'].sample}"
    mobile = next_mobile
    email  = next_email(company_name.split.first)
    corp_dob = Date.today - rand(30..60).years - rand(0..364).days
    nominee_first = FIRST_NAMES.sample

    c = Customer.new(
      customer_type: "corporate",
      company_name:  company_name,
      mobile:        mobile,
      email:         email,
      status:        true,
      address:       "#{rand(1..999)}, #{city} Industrial Area",
      state:         state,
      city:          city,
      pincode:       rand(100000..999999).to_s,
      gst_no:        rand_gst,
      birth_date:    corp_dob,
      nominee_name:  "#{nominee_first} #{LAST_NAMES.sample}",
      nominee_relation: ["spouse", "son", "daughter", "father", "mother"].sample,
      nominee_date_of_birth: Date.today - rand(20..55).years,
      additional_information: SEED_MARKER,
      sub_agent_id:  sub_agent_ids.sample
    )
  else
    first = FIRST_NAMES.sample
    last  = LAST_NAMES.sample
    dob   = Date.today - rand(22..65).years - rand(0..364).days
    mobile = next_mobile
    email  = next_email("#{first}.#{last}")

    c = Customer.new(
      customer_type:  "individual",
      first_name:     first,
      last_name:      last,
      birth_date:     dob,
      gender:         ["male", "female"].sample,
      marital_status: ["single", "married", "married", "divorced"].sample,
      mobile:         mobile,
      email:          email,
      status:         true,
      address:        "#{rand(1..999)}, #{['MG Road', 'Park Street', 'Main Bazaar', 'Church Road', 'Station Road'].sample}",
      state:          state,
      city:           city,
      pincode:        rand(100000..999999).to_s,
      annual_income:  [300_000, 500_000, 800_000, 1_200_000, 2_000_000, 5_000_000].sample,
      business_job:   ["Salaried", "Business", "Self Employed", "Professional", "Retired"].sample,
      nominee_name:   "#{FIRST_NAMES.sample} #{last}",
      nominee_relation: ["spouse", "son", "daughter", "father", "mother"].sample,
      nominee_date_of_birth: Date.today - rand(10..60).years,
      additional_information: SEED_MARKER,
      sub_agent_id:   sub_agent_ids.sample
    )
  end

  if c.save
    seed_customers << c
  else
    puts "  ✗ Customer #{i+1}: #{c.errors.full_messages.join(', ')}"
  end

  print "  #{seed_customers.size}/500\r" if (i + 1) % 50 == 0
end
puts "  ✓ #{seed_customers.size} customers created"
raise "No customers were created — fix validation errors above before continuing" if seed_customers.empty?

# ─── 4. LEADS (200) ───────────────────────────────────────────────────────────

puts "\n[4/9] Creating 200 Leads..."
seed_leads = []
stages      = %w[lead_generated consultation_scheduled one_on_one follow_up
                 follow_up_successful not_interested re_follow_up]
sources     = %w[online offline agent_referral walk_in tele_calling campaign]
subcategory_map = {
  "insurance" => %w[health life motor general],
  "investments" => %w[mutual_fund gold nps],
  "loans" => %w[personal home business]
}

200.times do |i|
  first  = FIRST_NAMES.sample
  last   = LAST_NAMES.sample
  mobile = next_mobile
  cat    = subcategory_map.keys.sample
  sub    = subcategory_map[cat].sample

  l = Lead.new(
    customer_type:       "individual",
    first_name:          first,
    last_name:           last,
    contact_number:      mobile,
    email:               next_email("lead.#{first}"),
    current_stage:       stages.sample,
    lead_source:         sources.sample,
    product_category:    cat,
    product_subcategory: sub,
    is_direct:           true,
    notes:               SEED_MARKER
  )

  if l.save
    seed_leads << l
  else
    puts "  ✗ Lead #{i+1}: #{l.errors.full_messages.join(', ')}"
  end
end
puts "  ✓ #{seed_leads.size} leads created"

# ─── 5. HEALTH INSURANCE (1600 – 40%) ────────────────────────────────────────

puts "\n[5/9] Creating 1600 Health Insurance policies..."
health_count    = 0
customers_cycle = seed_customers.cycle  # cycle through all 500 customers

1600.times do |i|
  customer     = customers_cycle.next
  start_date   = Date.today - rand(0..730).days
  end_date     = start_date + 1.year
  net_premium  = [5_000, 8_000, 10_000, 12_000, 15_000, 20_000, 25_000, 30_000].sample.to_f
  gst_pct      = 18.0
  sum_insured  = SUM_INSURED_OPTIONS.sample.to_f
  agency_code  = health_agency_codes.sample

  h = HealthInsurance.new(
    customer_id:              customer.id,
    policy_holder:            "Self",
    insurance_company_name:   HEALTH_COMPANIES.sample,
    policy_type:              "New",
    insurance_type:           HEALTH_INSURANCE_TYPES.sample,
    payment_mode:             PAYMENT_MODES_HEALTH.sample,
    policy_number:            next_policy_num("HLTH"),
    policy_booking_date:      start_date - rand(1..10).days,
    policy_start_date:        start_date,
    policy_end_date:          end_date,
    plan_name:                ["Super TopUp", "Family Health", "Senior Care", "Basic Shield", "Prime Cover"].sample,
    sum_insured:              sum_insured,
    net_premium:              net_premium,
    gst_percentage:           gst_pct,
    total_premium:            calc_premium(net_premium, gst_pct),
    main_agent_commission_percentage: 10.0,
    tds_percentage:           0.0,
    claim_process:            ["Inhouse", "TPA"].sample,
    agency_code_id:           agency_code.id,
    policy_added_by_admin:    true,
    is_admin_added:           true,
    is_customer_added:        false
  )

  if h.save
    health_count += 1
  else
    puts "  ✗ Health #{i+1}: #{h.errors.full_messages.first}" if i < 5
  end

  print "  #{health_count}/1600\r" if (i + 1) % 200 == 0
end
puts "  ✓ #{health_count} health policies created"

# ─── 6. LIFE INSURANCE (1600 – 40%) ──────────────────────────────────────────

puts "\n[6/9] Creating 1600 Life Insurance policies..."
life_count   = 0
policy_terms = [10, 15, 20, 25, 30]

1600.times do |i|
  customer     = customers_cycle.next
  start_date   = Date.today - rand(0..1825).days
  term_yrs     = policy_terms.sample
  end_date     = start_date + term_yrs.years
  net_premium  = [10_000, 15_000, 20_000, 25_000, 30_000, 50_000, 75_000, 100_000].sample.to_f
  gst_pct      = 4.5
  sum_insured  = [500_000, 1_000_000, 2_000_000, 5_000_000, 10_000_000].sample.to_f
  agency_code  = life_agency_codes.sample
  dist_id      = distributor_ids.sample

  l = LifeInsurance.new(
    customer_id:                    customer.id,
    distributor_id:                 dist_id,
    policy_holder:                  "Self",
    insurance_company_name:         LIFE_COMPANIES.sample,
    policy_type:                    "New",
    payment_mode:                   PAYMENT_MODES_LIFE.sample,
    policy_number:                  next_policy_num("LIFE"),
    policy_booking_date:            start_date - rand(1..10).days,
    policy_start_date:              start_date,
    policy_end_date:                end_date,
    plan_name:                      ["Term Plan", "Endowment", "ULIP", "Money Back", "Whole Life"].sample,
    sum_insured:                    sum_insured,
    net_premium:                    net_premium,
    first_year_gst_percentage:      gst_pct,
    total_premium:                  calc_premium(net_premium, gst_pct),
    policy_term:                    term_yrs,
    premium_payment_term:           [term_yrs, 10, 15].min,
    main_agent_commission_percentage: 8.0,
    tds_percentage:                 0.0,
    agency_code_id:                 agency_code.id,
    policy_added_by_admin:          true,
    is_admin_added:                 true,
    is_customer_added:              false
  )

  if l.save
    life_count += 1
  else
    puts "  ✗ Life #{i+1}: #{l.errors.full_messages.first}" if i < 5
  end

  print "  #{life_count}/1600\r" if (i + 1) % 200 == 0
end
puts "  ✓ #{life_count} life policies created"

# ─── 7. MOTOR INSURANCE (600 – 15%) ──────────────────────────────────────────

# Patch column name typo in motor insurance model (main_agent_tds_percentage → main_agent_tds_percent)
unless MotorInsurance.method_defined?(:main_agent_tds_percentage)
  MotorInsurance.class_eval do
    def main_agent_tds_percentage
      main_agent_tds_percent
    end
  end
end

puts "\n[7/9] Creating 600 Motor Insurance policies..."
motor_count    = 0
vehicle_makes  = ["Maruti", "Hyundai", "Honda", "Toyota", "Tata", "Mahindra", "Bajaj", "Hero", "TVS"]
vehicle_models = {
  "Maruti"   => ["Swift", "Baleno", "WagonR", "Alto", "Brezza"],
  "Hyundai"  => ["i20", "Creta", "Verna", "Tucson", "i10"],
  "Honda"    => ["City", "Amaze", "WR-V", "Jazz", "CB300R"],
  "Toyota"   => ["Innova", "Fortuner", "Camry", "Glanza", "Urban Cruiser"],
  "Tata"     => ["Nexon", "Harrier", "Altroz", "Safari", "Punch"],
  "Mahindra" => ["XUV700", "Scorpio", "Thar", "Bolero", "XUV300"],
  "Bajaj"    => ["Pulsar", "Dominar", "Platina", "CT100", "Avenger"],
  "Hero"     => ["Splendor", "HF Deluxe", "Glamour", "Xtreme", "Passion"],
  "TVS"      => ["Apache", "Jupiter", "Star City", "Ntorq", "XL100"]
}

reg_prefix = %w[MH KA TN DL GJ RJ UP HR PB]

600.times do |i|
  customer     = customers_cycle.next
  start_date   = Date.today - rand(0..365).days
  end_date     = start_date + 1.year
  ins_type     = MOTOR_INSURANCE_TYPES.sample
  net_premium  = [4_000, 6_000, 8_000, 10_000, 12_000, 15_000, 20_000].sample.to_f
  gst_pct      = 18.0
  make         = vehicle_makes.sample
  model_name   = vehicle_models[make].sample
  reg_no       = "#{reg_prefix.sample}#{rand(10..99)}#{('A'..'Z').to_a.sample(2).join}#{rand(1000..9999)}"
  vehicle_type = MOTOR_VEHICLE_TYPES.sample
  vehicle_idv  = ins_type == "Third Party" ? nil : [150_000, 300_000, 500_000, 800_000, 1_200_000].sample.to_f
  agency_code  = motor_agency_codes.sample

  m = MotorInsurance.new(
    customer_id:            customer.id,
    policy_holder:          "Self",
    insurance_company_name: MOTOR_COMPANIES.sample,
    vehicle_type:           vehicle_type,
    class_of_vehicle:       MOTOR_CLASS_OF_VEHICLE.sample,
    insurance_type:         ins_type,
    policy_type:            "New",
    payment_mode:           PAYMENT_MODES_MOTOR.sample,
    policy_number:          next_policy_num("MOTR"),
    policy_booking_date:    start_date - rand(1..7).days,
    policy_start_date:      start_date,
    policy_end_date:        end_date,
    registration_number:    reg_no,
    make:                   make,
    model:                  model_name,
    vehicle_idv:            vehicle_idv,
    cng_idv:                nil,
    net_premium:            net_premium,
    gst_percentage:         gst_pct,
    total_premium:          calc_premium(net_premium, gst_pct),
    main_agent_commission_percentage: 7.5,
    tds_percentage:         0.0,
    agency_code_id:         agency_code.id,
    policy_added_by_admin:  true,
    is_admin_added:         true,
    is_customer_added:      false
  )

  if m.save
    motor_count += 1
  else
    puts "  ✗ Motor #{i+1}: #{m.errors.full_messages.first}" if i < 5
  end

  print "  #{motor_count}/600\r" if (i + 1) % 100 == 0
end
puts "  ✓ #{motor_count} motor policies created"

# ─── 8. OTHER INSURANCE (200 – 5%) ───────────────────────────────────────────

puts "\n[8/9] Creating 200 Other Insurance policies..."
other_count = 0

200.times do |i|
  customer    = customers_cycle.next
  start_date  = Date.today - rand(0..365).days
  end_date    = start_date + 1.year
  net_premium = [3_000, 5_000, 8_000, 10_000, 15_000].sample.to_f
  gst_pct     = 18.0
  sum_vals    = [500_000, 1_000_000, 2_000_000, 5_000_000].sample.to_f

  o = OtherInsurance.new(
    customer_id:            customer.id,
    policy_holder:          "Self",
    insurance_company_name: OTHER_COMPANIES.sample,
    insurance_type:         OTHER_INSURANCE_TYPES.sample,
    policy_type:            "New",
    payment_mode:           PAYMENT_MODES_OTHER.sample,
    policy_number:          next_policy_num("OTHR"),
    policy_booking_date:    start_date - rand(1..5).days,
    policy_start_date:      start_date,
    policy_end_date:        end_date,
    sum_insured:            sum_vals,
    net_premium:            net_premium,
    gst_percentage:         gst_pct,
    total_premium:          calc_premium(net_premium, gst_pct),
    status:                 "Active",
    main_agent_commission_percentage: 8.0,
    tds_percentage:         0.0,
    policy_added_by_admin:  true,
    is_admin_added:         true,
    is_customer_added:      false
  )

  if o.save
    other_count += 1
  else
    puts "  ✗ Other #{i+1}: #{o.errors.full_messages.first}" if i < 5
  end
end
puts "  ✓ #{other_count} other policies created"

# ─── 9. RENEWALS (~10% per type) ─────────────────────────────────────────────

puts "\n[9a] Creating Health renewals..."
renewal_health = 0
HealthInsurance.where(policy_type: "New")
               .where("additional_information IS NULL OR additional_information != ?", SEED_MARKER)
               .joins(:customer)
               .where("customers.additional_information = ?", SEED_MARKER)
               .limit(160).each do |orig|
  net    = (orig.net_premium * 1.1).round(2)
  gst    = orig.gst_percentage
  h = HealthInsurance.new(
    customer_id:              orig.customer_id,
    policy_holder:            orig.policy_holder,
    insurance_company_name:   orig.insurance_company_name,
    policy_type:              "Renewal",
    insurance_type:           orig.insurance_type,
    payment_mode:             orig.payment_mode,
    policy_number:            next_policy_num("HLTH"),
    policy_booking_date:      orig.policy_end_date,
    policy_start_date:        orig.policy_end_date,
    policy_end_date:          orig.policy_end_date + 1.year,
    plan_name:                orig.plan_name,
    sum_insured:              orig.sum_insured,
    net_premium:              net,
    gst_percentage:           gst,
    total_premium:            calc_premium(net, gst),
    main_agent_commission_percentage: 10.0,
    tds_percentage:           0.0,
    claim_process:            orig.claim_process,
    agency_code_id:           orig.agency_code_id,
    original_policy_id:       orig.id,
    policy_added_by_admin:    true,
    is_admin_added:           true,
    is_customer_added:        false
  )
  renewal_health += 1 if h.save
end
puts "  ✓ #{renewal_health} health renewals"

puts "\n[9b] Creating Life renewals..."
renewal_life = 0
LifeInsurance.joins(:customer)
             .where("customers.additional_information = ?", SEED_MARKER)
             .limit(160).each do |orig|
  net  = (orig.net_premium * 1.05).round(2)
  gst  = orig.first_year_gst_percentage
  l = LifeInsurance.new(
    customer_id:                  orig.customer_id,
    distributor_id:               orig.distributor_id,
    policy_holder:                orig.policy_holder,
    insurance_company_name:       orig.insurance_company_name,
    policy_type:                  "Renewal",
    payment_mode:                 orig.payment_mode,
    policy_number:                next_policy_num("LIFE"),
    policy_booking_date:          orig.policy_end_date,
    policy_start_date:            orig.policy_end_date,
    policy_end_date:              orig.policy_end_date + orig.policy_term.to_i.years,
    plan_name:                    orig.plan_name,
    sum_insured:                  orig.sum_insured,
    net_premium:                  net,
    first_year_gst_percentage:    gst,
    total_premium:                calc_premium(net, gst),
    policy_term:                  orig.policy_term,
    premium_payment_term:         orig.premium_payment_term,
    main_agent_commission_percentage: 8.0,
    tds_percentage:               0.0,
    agency_code_id:               orig.agency_code_id,
    original_policy_id:           orig.id,
    policy_added_by_admin:        true,
    is_admin_added:               true,
    is_customer_added:            false
  )
  renewal_life += 1 if l.save
end
puts "  ✓ #{renewal_life} life renewals"

puts "\n[9c] Creating Motor renewals..."
renewal_motor = 0
MotorInsurance.joins(:customer)
              .where("customers.additional_information = ?", SEED_MARKER)
              .limit(60).each do |orig|
  net = (orig.net_premium * 1.08).round(2)
  gst = orig.gst_percentage
  m = MotorInsurance.new(
    customer_id:            orig.customer_id,
    policy_holder:          orig.policy_holder,
    insurance_company_name: orig.insurance_company_name,
    vehicle_type:           orig.vehicle_type,
    class_of_vehicle:       orig.class_of_vehicle,
    insurance_type:         orig.insurance_type,
    policy_type:            "Renewal",
    payment_mode:           orig.payment_mode,
    policy_number:          next_policy_num("MOTR"),
    policy_booking_date:    orig.policy_end_date,
    policy_start_date:      orig.policy_end_date,
    policy_end_date:        orig.policy_end_date + 1.year,
    registration_number:    orig.registration_number,
    make:                   orig.make,
    model:                  orig.model,
    vehicle_idv:            orig.vehicle_idv,
    net_premium:            net,
    gst_percentage:         gst,
    total_premium:          calc_premium(net, gst),
    main_agent_commission_percentage: 7.5,
    tds_percentage:         0.0,
    agency_code_id:         orig.agency_code_id,
    policy_added_by_admin:  true,
    is_admin_added:         true,
    is_customer_added:      false
  )
  renewal_motor += 1 if m.save
end
puts "  ✓ #{renewal_motor} motor renewals"

# ─── 10. BANNERS ──────────────────────────────────────────────────────────────

puts "\n[10] Creating Banners..."
banner_data = [
  { title: "Health Insurance Summer Offer", display_location: "dashboard",
    display_order: 1, description: "Get 20% off on all health plans this summer" },
  { title: "LIC New Term Plan Launch", display_location: "home",
    display_order: 2, description: "LIC's new term plan with enhanced coverage" },
  { title: "Motor Policy Renewal Reminder", display_location: "dashboard",
    display_order: 3, description: "Renew your motor policy before it expires" },
  { title: "Free Financial Planning Session", display_location: "sidebar",
    display_order: 4, description: "Book a free 30-min consultation with our experts" },
  { title: "Tax Saving Investment Plans", display_location: "home",
    display_order: 5, description: "Save up to ₹1.5L tax with ELSS and insurance" },
]
seed_banners = []
banner_data.each do |bd|
  b = Banner.find_or_initialize_by(title: bd[:title])
  b.assign_attributes(
    display_location:  bd[:display_location],
    display_order:     bd[:display_order],
    description:       "#{bd[:description]} [#{SEED_MARKER}]",
    display_start_date: Date.today,
    display_end_date:   Date.today + 6.months,
    status:            true
  )
  b.save!
  seed_banners << b
end
puts "  ✓ #{seed_banners.size} banners created"

# ─── SUMMARY ──────────────────────────────────────────────────────────────────

total_policies = health_count + renewal_health + life_count + renewal_life +
                 motor_count + renewal_motor + other_count

puts "\n" + "=" * 60
puts "SEED COMPLETE"
puts "=" * 60
puts "  Brokers         : #{seed_brokers.size}"
puts "  Agency Codes    : #{seed_agency_codes.size}"
puts "  Customers       : #{seed_customers.size}"
puts "  Leads           : #{seed_leads.size}"
puts "  Health Insurance: #{health_count} new + #{renewal_health} renewals = #{health_count + renewal_health}"
puts "  Life Insurance  : #{life_count} new + #{renewal_life} renewals = #{life_count + renewal_life}"
puts "  Motor Insurance : #{motor_count} new + #{renewal_motor} renewals = #{motor_count + renewal_motor}"
puts "  Other Insurance : #{other_count}"
puts "  TOTAL POLICIES  : #{total_policies}"
puts "  Banners         : #{seed_banners.size}"
puts ""
puts "  To erase all seed data run: rails runner cleanup_bulk_seed.rb"
puts "=" * 60
