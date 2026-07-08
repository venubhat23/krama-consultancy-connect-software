# Run with: rails runner seed_insurance_companies.rb

life_companies = [
  "Aditya Birla Sun Life Insurance",
  "Axis Max Life Insurance",
  "Bajaj Allianz Life Insurance",
  "Canara HSBC Life Insurance",
  "Edelweiss Life Insurance",
  "Go Digit Life Insurance Limited",
  "HDFC Life Insurance",
  "ICICI Prudential Life Insurance",
  "Kotak Life Insurance",
  "LIC",
  "Reliance Nippon Life Insurance Company",
  "SBI Life Insurance",
  "Shriram Life Insurance",
  "TATA AIA Life Insurance",
]

motor_other_companies = [
  "Agriculture Insurance Company of India",
  "Bajaj Allianz General Insurance",
  "Cholamandalam MS General Insurance",
  "ECGC Limited",
  "Future Generali India Insurance",
  "Go Digit Insurance",
  "HDFC ERGO General Insurance",
  "ICICI Lombard",
  "IFFCO TOKIO General Insurance",
  "Kshema General Insurance Limited",
  "Liberty General Insurance",
  "Magma General Insurance",
  "National Insurance Company",
  "Navi General Insurance Limited",
  "New India Assurance",
  "Raheja QBE General Insurance",
  "Reliance General Insurance",
  "Royal Sundaram General Insurance",
  "SBI General Insurance",
  "Shriram General Insurance",
  "Tata AIG General Insurance",
  "The Oriental Insurance Company",
  "United India Insurance Company",
  "Universal Sompo General Insurance",
  "Zuno General Insurance",
  "Zurich Kotak General Insurance",
]

health_companies = [
  "Aditya Birla Health Insurance",
  "Bajaj Allianz General Insurance",
  "Care Health Insurance Ltd",
  "Galaxy Health Insurance Company Ltd",
  "HDFC ERGO General Insurance",
  "ICICI Lombard",
  "Manipal Cigna Health Insurance Company Ltd",
  "National Insurance Company",
  "New India Assurance",
  "Niva Bupa Health Insurance",
  "Reliance General Insurance",
  "Royal Sundaram General Insurance",
  "SBI General Insurance",
  "Star Health and Allied Insurance Company Ltd",
  "Tata AIG General Insurance",
  "The Oriental Insurance Company",
  "United India Insurance Company",
  "Zurich Kotak General Insurance",
]

created = 0
skipped = 0

[
  { type: "life",        names: life_companies        },
  { type: "motor_other", names: motor_other_companies },
  { type: "health",      names: health_companies      },
].each do |group|
  group[:names].each do |name|
    if InsuranceCompany.exists?(name: name, insurance_type: group[:type])
      puts "  skip  [#{group[:type]}] #{name}"
      skipped += 1
      next
    end

    company = InsuranceCompany.create(
      name:           name,
      insurance_type: group[:type],
      status:         true,
    )

    if company.persisted?
      puts "  ✓ created [#{group[:type]}] #{name}"
      created += 1
    else
      puts "  ✗ FAILED  [#{group[:type]}] #{name}: #{company.errors.full_messages.join(', ')}"
    end
  end
end

puts "\n--- Summary ---"
puts "Created : #{created}"
puts "Skipped : #{skipped} (already exist)"
puts "DB total: #{InsuranceCompany.count}"
