# Run with: rails runner seed_investors.rb
# NOTE: Run `rails db:migrate` first if invested_amount / investment_percentage /
# number_of_shares columns are missing.

investors_data = [
  { name: "DEVARAJ JAYRAM",            shares: 2, invested_amount: 200_000, sharing_pct: 100.00 },
  { name: "DEVARAJ TH",                shares: 2, invested_amount: 200_000, sharing_pct: 100.00 },
  { name: "GOPAL N",                   shares: 1, invested_amount:  25_000, sharing_pct:  25.00 },
  { name: "MANJUNATHA R",              shares: 1, invested_amount: 100_000, sharing_pct: 100.00 },
  { name: "YOGESH SLV",                shares: 1, invested_amount:  25_000, sharing_pct:  25.00 },
  { name: "NIRANJAN",                  shares: 2, invested_amount: 200_000, sharing_pct: 100.00 },
  { name: "KRISHNA MURTHY",            shares: 2, invested_amount: 200_000, sharing_pct: 100.00 },
  { name: "ASHOK B",                   shares: 2, invested_amount: 200_000, sharing_pct: 100.00 },
  { name: "SHIVAKUMAR B N",            shares: 1, invested_amount: 100_000, sharing_pct: 100.00 },
  { name: "VIJENDRA M P",              shares: 2, invested_amount: 200_000, sharing_pct: 100.00 },
  { name: "MURALI KRISHNA KASIBHATTA", shares: 2, invested_amount: 200_000, sharing_pct: 100.00 },
  { name: "NITIN KUMAR S",             shares: 2, invested_amount: 200_000, sharing_pct: 100.00 },
  { name: "ADITHYA TANMOY",            shares: 1, invested_amount: 100_000, sharing_pct: 100.00 },
]

has_investment_cols = Investor.column_names.include?("invested_amount")

created = 0
failed  = 0

investors_data.each_with_index do |data, index|
  parts      = data[:name].split
  first_name = parts[0].capitalize
  last_name  = parts.length > 1 ? parts.last.capitalize : first_name
  middle_name = parts.length > 2 ? parts[1..-2].map(&:capitalize).join(" ") : nil

  # Placeholder mobile & email — update after creation if needed
  mobile = "900000#{(index + 1).to_s.rjust(4, '0')}"
  email  = "investor#{index + 1}@insurebook.placeholder"

  attrs = {
    first_name:  first_name,
    middle_name: middle_name,
    last_name:   last_name,
    mobile:      mobile,
    email:       email,
    status:      :active,
  }

  if has_investment_cols
    attrs[:number_of_shares]      = data[:shares]
    attrs[:invested_amount]       = data[:invested_amount]
    attrs[:investment_percentage] = data[:sharing_pct]
  end

  investor = Investor.new(attrs)

  if investor.save
    puts "✓ Created: #{investor.full_name} (username: #{investor.username})"
    created += 1
  else
    puts "✗ FAILED  #{data[:name]}: #{investor.errors.full_messages.join(', ')}"
    failed += 1
  end
end

puts "\n--- Summary ---"
puts "Created : #{created}"
puts "Failed  : #{failed}"
puts "Total investors in DB: #{Investor.count}"

unless has_investment_cols
  puts "\n⚠ Investment columns (invested_amount, investment_percentage, number_of_shares)"
  puts "  were NOT set — run `rails db:migrate` then re-run this script."
end
