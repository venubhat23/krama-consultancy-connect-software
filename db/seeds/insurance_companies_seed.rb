#!/usr/bin/env ruby
# Insurance Companies Seed Script
# This script populates the insurance_companies table with data from InsuranceCompanyHelper
# Run with: rails runner db/seeds/insurance_companies_seed.rb

require_relative '../../app/helpers/insurance_company_helper'

class InsuranceCompaniesSeeder
  include InsuranceCompanyHelper

  def self.seed!
    new.seed_insurance_companies
  end

  def seed_insurance_companies
    puts "🏢 Seeding Insurance Companies..."
    puts "=" * 50

    # Clear existing data (optional)
    if InsuranceCompany.count > 0
      puts "⚠️  Found #{InsuranceCompany.count} existing companies."
      print "Do you want to clear existing data? (y/N): "
      response = STDIN.gets.chomp.downcase

      if response == 'y' || response == 'yes'
        puts "🗑️  Clearing existing insurance companies..."
        InsuranceCompany.delete_all
        puts "✅ Existing data cleared."
      else
        puts "📝 Keeping existing data. Only adding missing companies."
      end
    end

    # Seed companies from InsuranceCompanyHelper
    companies_created = 0
    companies_skipped = 0

    INSURANCE_COMPANIES.each_with_index do |(company_name, company_type), index|
      # Check if company already exists
      existing_company = InsuranceCompany.find_by(name: company_name)

      if existing_company
        puts "⏭️  Skipping #{company_name} (already exists)"
        companies_skipped += 1
        next
      end

      # Generate a simple code from the company name
      company_code = generate_company_code(company_name)

      # Create the insurance company
      begin
        insurance_company = InsuranceCompany.create!(
          name: company_name,
          code: company_code,
          status: true,
          contact_person: generate_contact_person(company_name),
          email: generate_company_email(company_name),
          mobile: generate_company_mobile,
          address: generate_company_address(company_name)
        )

        puts "✅ Created: #{company_name} (#{company_type}) - Code: #{company_code}"
        companies_created += 1

      rescue ActiveRecord::RecordInvalid => e
        puts "❌ Failed to create #{company_name}: #{e.message}"
      end
    end

    puts "=" * 50
    puts "🎉 Insurance Companies Seeding Complete!"
    puts "📊 Statistics:"
    puts "   • Companies created: #{companies_created}"
    puts "   • Companies skipped: #{companies_skipped}"
    puts "   • Total companies in DB: #{InsuranceCompany.count}"
    puts "   • Health companies: #{health_insurance_companies.count}"
    puts "   • General companies: #{general_insurance_companies.count}"

    # Verify seeding
    verify_seeding
  end

  private

  def generate_company_code(company_name)
    # Extract meaningful parts and create a code
    words = company_name.split(/\s+/)

    # Try to create a meaningful code
    if words.length >= 2
      # Take first letter of each significant word
      significant_words = words.reject { |w| w.downcase.in?(['insurance', 'company', 'limited', 'ltd', 'co', 'general', 'health']) }

      if significant_words.length >= 2
        significant_words.first(3).map { |w| w[0].upcase }.join
      else
        # Fallback to first letters of all words
        words.first(3).map { |w| w[0].upcase }.join
      end
    else
      # Single word, take first 3 letters
      company_name.gsub(/[^A-Za-z]/, '').first(3).upcase
    end
  end

  def generate_contact_person(company_name)
    # Extract company name for realistic contact person
    first_names = ['Rajesh', 'Priya', 'Amit', 'Sneha', 'Vikram', 'Kavya', 'Suresh', 'Anita', 'Manoj', 'Deepika']
    last_names = ['Kumar', 'Sharma', 'Patel', 'Singh', 'Gupta', 'Reddy', 'Joshi', 'Nair', 'Agarwal', 'Mishra']

    "#{first_names.sample} #{last_names.sample}"
  end

  def generate_company_email(company_name)
    # Create email from company name
    domain_name = company_name.downcase
                              .gsub(/[^a-z0-9\s]/, '')
                              .split.first(2)
                              .join('')
                              .gsub(/insurance|company|limited|ltd|general|health/, '')
                              .strip

    domain_name = company_name.split.first.downcase.gsub(/[^a-z]/, '') if domain_name.empty?
    domain_name = 'company' if domain_name.empty?

    "contact@#{domain_name}.com"
  end

  def generate_company_mobile
    # Generate realistic Indian mobile number
    "#{['+91-', ''].sample}#{['9', '8', '7'].sample}#{rand(100000000..999999999)}"
  end

  def generate_company_address(company_name)
    cities = ['Mumbai', 'Delhi', 'Bangalore', 'Chennai', 'Hyderabad', 'Pune', 'Kolkata', 'Ahmedabad']
    sectors = ['Sector 1', 'Sector 5', 'Andheri East', 'Bandra West', 'Connaught Place', 'MG Road', 'Brigade Road']

    city = cities.sample
    sector = sectors.sample
    building_number = rand(1..999)

    "#{building_number} Corporate Plaza, #{sector}, #{city} - #{rand(100000..999999)}"
  end

  def verify_seeding
    puts "\n🔍 Verification:"

    # Check health insurance companies
    health_companies = InsuranceCompany.where(
      name: health_insurance_companies
    ).count
    puts "   • Health companies in DB: #{health_companies}/#{health_insurance_companies.count}"

    # Check general insurance companies
    general_companies = InsuranceCompany.where(
      name: general_insurance_companies
    ).count
    puts "   • General companies in DB: #{general_companies}/#{general_insurance_companies.count}"

    # Sample companies
    puts "\n📋 Sample companies created:"
    InsuranceCompany.limit(5).each do |company|
      company_type = insurance_company_type(company.name) || 'UNKNOWN'
      puts "   • #{company.name} (#{company_type}) - #{company.code}"
    end

    if InsuranceCompany.count == INSURANCE_COMPANIES.count
      puts "\n✅ All companies seeded successfully!"
    else
      puts "\n⚠️  Expected #{INSURANCE_COMPANIES.count} companies, but have #{InsuranceCompany.count} in database."
    end
  end
end

# Run the seeder
if __FILE__ == $0
  InsuranceCompaniesSeeder.seed!
end