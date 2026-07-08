puts '🔍 Testing Notification System...'

# Find test data
sub_agent = SubAgent.first
admin_user = User.first
ticket = ClientRequest.where(submitter_type: 'SubAgent').first

if sub_agent.nil? || admin_user.nil?
  puts '❌ Missing test data (sub_agent or admin_user)'
  exit
end

puts "✅ Using SubAgent: #{sub_agent.full_name}"
puts "✅ Using Admin User: #{admin_user.full_name}"

# Test 1: Create/Update ticket with admin response
if ticket.nil?
  puts '📋 Creating new test ticket...'
  ticket = ClientRequest.create!(
    name: sub_agent.full_name,
    email: sub_agent.email,
    phone_number: sub_agent.mobile,
    subject: 'Test Notification System',
    description: 'Testing notification creation when admin adds response',
    category: 'technical_support',
    priority: 'medium',
    status: 'in_progress',
    submitter_type: 'SubAgent',
    submitter_id: sub_agent.id,
    resolved_by: admin_user
  )
  puts "✅ Created ticket: #{ticket.ticket_number}"
else
  puts "✅ Using existing ticket: #{ticket.ticket_number}"
end

# Test 2: Add admin response to trigger notification
puts
puts '📧 Adding admin response to trigger notification...'
initial_notification_count = Notification.count
ticket.update!(admin_response: 'Hello! We have received your request and are working on it. We will update you shortly with our findings.')

puts "✅ Admin response added: #{ticket.admin_response[0..50]}..."

# Test 3: Check if notification was created
new_notification_count = Notification.count
notifications_created = new_notification_count - initial_notification_count

puts
puts '📊 Notification Creation Results:'
puts "   Notifications before: #{initial_notification_count}"
puts "   Notifications after: #{new_notification_count}"
puts "   New notifications: #{notifications_created}"

if notifications_created > 0
  notification = Notification.last
  puts
  puts '✅ Notification successfully created!'
  puts "   ID: #{notification.id}"
  puts "   Type: #{notification.notification_type}"
  puts "   Title: #{notification.title}"
  puts "   Message: #{notification.message}"
  puts "   Recipient: #{notification.recipient_type}##{notification.recipient_id}"
  puts "   Reference: #{notification.reference_type}##{notification.reference_id}"
  puts "   Is Read: #{notification.is_read}"

  # Test 4: Test API response structure
  puts
  puts '🔌 Testing API Response Structure:'
  api_response = {
    id: notification.id,
    notification_type: notification.notification_type,
    title: notification.title,
    message: notification.message,
    is_read: notification.is_read,
    sent_at: notification.sent_at,
    read_at: notification.read_at,
    reference: notification.reference ? {
      type: notification.reference_type,
      id: notification.reference_id,
      details: {
        ticket_number: notification.reference.ticket_number,
        subject: notification.reference.subject,
        status: notification.reference.status
      }
    } : nil,
    created_at: notification.created_at
  }

  puts "   API Response:"
  api_response.each { |k, v| puts "     #{k}: #{v}" }

else
  puts '❌ No notification was created'
end

puts
puts '🎉 Notification system test completed!'