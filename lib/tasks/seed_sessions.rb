# Create test session data for demonstration
require 'securerandom'

puts 'Creating test session data...'

# Different device types
devices = ['Desktop', 'Mobile', 'Tablet']
browsers = ['Chrome', 'Safari', 'Firefox', 'Edge']
os_list = ['Windows', 'Mac OS X', 'iOS', 'Android', 'Linux']
countries = ['United States', 'India', 'United Kingdom', 'Canada', 'Australia']

# Create visits for the last 30 days
30.times do |i|
  date = (30 - i).days.ago

  # Create 5-20 visits per day
  rand(5..20).times do
    visit = Ahoy::Visit.create!(
      visit_token: SecureRandom.hex(16),
      visitor_token: SecureRandom.hex(16),
      user_id: User.pluck(:id).sample,
      ip: "192.168.1.#{rand(1..255)}",
      user_agent: "Mozilla/5.0",
      referrer: [nil, 'https://google.com', 'https://facebook.com', 'https://linkedin.com'].sample,
      referring_domain: [nil, 'google.com', 'facebook.com', 'linkedin.com'].sample,
      landing_page: '/',
      browser: browsers.sample,
      os: os_list.sample,
      device_type: devices.sample,
      country: countries.sample,
      started_at: date + rand(0..23).hours + rand(0..59).minutes
    )

    # Create 1-10 events per visit
    rand(1..10).times do |j|
      Ahoy::Event.create!(
        visit: visit,
        user_id: visit.user_id,
        name: ['$view', 'Viewed page', 'Clicked button'].sample,
        properties: {
          page: ['/admin/dashboard', '/admin/customers', '/admin/health_insurances', '/admin/life_insurances', '/admin/analytics', '/admin/reports/sessions'].sample,
          controller: ['dashboard', 'customers', 'health_insurances', 'life_insurances'].sample,
          action: ['index', 'show', 'new', 'edit'].sample
        },
        time: visit.started_at + j.minutes
      )
    end
  end
end

# Create some recent active sessions (last 30 minutes)
5.times do
  visit = Ahoy::Visit.create!(
    visit_token: SecureRandom.hex(16),
    visitor_token: SecureRandom.hex(16),
    user_id: User.pluck(:id).sample,
    ip: "192.168.1.#{rand(1..255)}",
    user_agent: "Mozilla/5.0",
    referrer: nil,
    browser: browsers.sample,
    os: os_list.sample,
    device_type: devices.sample,
    country: countries.sample,
    started_at: rand(0..29).minutes.ago
  )

  # Create a few events
  rand(1..3).times do |j|
    Ahoy::Event.create!(
      visit: visit,
      user_id: visit.user_id,
      name: '$view',
      properties: {
        page: ['/admin/dashboard', '/admin/reports/sessions'].sample
      },
      time: visit.started_at + j.minutes
    )
  end
end

puts "✅ Created #{Ahoy::Visit.count} visits with #{Ahoy::Event.count} events"
puts "   Active users (last 30 min): #{Ahoy::Visit.where('started_at > ?', 30.minutes.ago).count}"
puts "   Today's sessions: #{Ahoy::Visit.where(started_at: Date.current.all_day).count}"