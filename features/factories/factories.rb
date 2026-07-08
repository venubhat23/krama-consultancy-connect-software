return if FactoryBot.factories.map(&:name).include?(:role)

FactoryBot.define do
  factory :role do
    name { "Admin" }
    description { "Administrator role" }
    status { true }
  end

  factory :user do
    first_name { "Test" }
    last_name  { "Admin" }
    sequence(:email) { |n| "admin#{n}@drwise.com" }
    password { "password123" }
    password_confirmation { "password123" }
    role { association :role }
  end

  factory :customer do
    customer_type { "Individual" }
    first_name    { Faker::Name.first_name }
    last_name     { Faker::Name.last_name }
    sequence(:email) { |n| "customer#{n}@example.com" }
    sequence(:mobile) { |n| "9#{n.to_s.rjust(9, '0')}" }
    city   { "Mumbai" }
    state  { "Maharashtra" }
  end

  factory :distributor do
    first_name { "Dist" }
    last_name  { "Agent" }
    sequence(:mobile) { |n| "8#{n.to_s.rjust(9, '0')}" }
    sequence(:email)  { |n| "dist#{n}@drwise.com" }
    role_id { 1 }
  end

  factory :insurance_company do
    sequence(:name) { |n| "Test Insurance Co #{n}" }
    status { true }
    sequence(:code) { |n| "TIC#{n}" }
  end

  factory :agency_code do
    insurance_type { "Life Insurance" }
    company_name   { "Test Insurance Co 1" }
    agent_name     { "Test Agent" }
    sequence(:code) { |n| "AG#{n.to_s.rjust(4, '0')}" }
  end

  factory :sub_agent do
    first_name { Faker::Name.first_name }
    last_name  { Faker::Name.last_name }
    sequence(:mobile) { |n| "7#{n.to_s.rjust(9, '0')}" }
    sequence(:email)  { |n| "affiliate#{n}@drwise.com" }
    password { "Password@123" }
    password_confirmation { "Password@123" }
    association :role
  end

  factory :investor do
    first_name { Faker::Name.first_name }
    last_name  { Faker::Name.last_name }
    sequence(:mobile) { |n| "6#{n.to_s.rjust(9, '0')}" }
    sequence(:email)  { |n| "investor#{n}@invest.com" }
    sequence(:username) { |n| "investor#{n}" }
    role_id { 1 }
  end

  factory :life_insurance do
    association :customer
    association :distributor
    policy_holder          { "Self" }
    insurance_company_name { "Test Insurance Co 1" }
    policy_type            { "New" }
    payment_mode           { "Yearly" }
    sequence(:policy_number) { |n| "LIFE#{n.to_s.rjust(6, '0')}" }
    policy_booking_date    { Date.today }
    policy_start_date      { Date.today }
    policy_end_date        { 10.years.from_now.to_date }
    sum_insured            { 5000000 }
    net_premium            { 50000 }
    total_premium          { 54500 }
    first_year_gst_percentage { 4.5 }
    policy_term            { 10 }
    is_admin_added         { true }
  end
end
