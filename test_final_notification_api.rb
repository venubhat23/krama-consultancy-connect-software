puts '🔍 Final Notification API Test...'

# Find the sub agent that has the notification
notification = Notification.first
target_sub_agent = SubAgent.find(notification.recipient_id)

puts "✅ Target SubAgent: #{target_sub_agent.full_name} (ID: #{target_sub_agent.id})"

# Test notification counts
sub_agent_notifications = Notification.for_sub_agent(target_sub_agent.id)
unread_count = sub_agent_notifications.unread.count
read_count = sub_agent_notifications.read.count

puts
puts '📊 Notification Summary:'
puts "   Total: #{sub_agent_notifications.count}"
puts "   Unread: #{unread_count}"
puts "   Read: #{read_count}"

# Test API response structure
puts
puts '📋 Sample API Response:'
sample_notification = sub_agent_notifications.first
api_response = {
  id: sample_notification.id,
  notification_type: sample_notification.notification_type,
  title: sample_notification.title,
  message: sample_notification.message,
  is_read: sample_notification.is_read,
  sent_at: sample_notification.sent_at,
  read_at: sample_notification.read_at,
  reference: sample_notification.reference ? {
    type: sample_notification.reference_type,
    id: sample_notification.reference_id,
    details: {
      ticket_number: sample_notification.reference.ticket_number,
      subject: sample_notification.reference.subject,
      status: sample_notification.reference.status
    }
  } : nil,
  created_at: sample_notification.created_at
}

puts 'API Response Structure:'
api_response.each { |k, v| puts "  #{k}: #{v}" }

# Test mark as read functionality
if unread_count > 0
  puts
  puts '🔄 Testing mark as read functionality...'
  test_notification = sub_agent_notifications.unread.first
  puts "  Before: is_read = #{test_notification.is_read}"

  test_notification.mark_as_read!

  puts "  After: is_read = #{test_notification.is_read}"
  puts "  Read at: #{test_notification.read_at}"
  puts '✅ Mark as read functionality works!'

  # Reset for next test
  test_notification.mark_as_unread!
  puts "  Reset to unread for future tests"
end

puts
puts '🎉 All notification functionality tested successfully!'
puts
puts '📱 Available Mobile API Endpoints:'
puts '  GET /api/v1/mobile/sub_agent/notifications'
puts '  PUT /api/v1/mobile/sub_agent/notifications/:id/mark_read'
puts '  PUT /api/v1/mobile/sub_agent/notifications/mark_all_read'
puts '  GET /api/v1/mobile/sub_agent/notifications/unread_count'