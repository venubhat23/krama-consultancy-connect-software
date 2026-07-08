# Seed data for the Forum Platform (super_admin / forum_admin / chapter_admin / member).
# Run with: RAILS_ENV=development bin/rails runner db/seeds/forum_platform.rb
puts "== Seeding Forum Platform =="

# --- Business Plans ---------------------------------------------------------
bronze = BusinessPlan.find_or_create_by!(key: "bronze") do |p|
  p.name = "Bronze"; p.price = 999; p.chapter_limit = 2; p.member_limit = 5
  p.description = "Starter tier for a single small forum."
end
silver = BusinessPlan.find_or_create_by!(key: "silver") do |p|
  p.name = "Silver"; p.price = 2499; p.chapter_limit = 5; p.member_limit = 20
  p.description = "Growing forums with a few chapters."
end
gold = BusinessPlan.find_or_create_by!(key: "gold") do |p|
  p.name = "Gold"; p.price = 4999; p.chapter_limit = nil; p.member_limit = nil
  p.description = "Unlimited chapters and members."
end
puts "Business plans: #{BusinessPlan.count}"

SystemSetting.set_default_business_plan_key("bronze")

# --- Super Admin -------------------------------------------------------------
super_admin_role = Role.find_or_create_by!(name: "super_admin") do |r|
  r.description = "Full platform access"
  r.status = true
end

super_admin = User.find_or_initialize_by(email: "admin@krama.com")
super_admin.assign_attributes(
  first_name: "Krama", last_name: "Admin", mobile: "9000000001",
  password: "admin123", password_confirmation: "admin123",
  user_type: "admin", role: super_admin_role, status: true
)
super_admin.save!
puts "Super admin: #{super_admin.email} / admin123"

# --- Sample Forum, Chapters, Admins, Members ---------------------------------
forum = Forum.find_or_create_by!(name: "Krama Business Network") do |f|
  f.business_plan = gold
end

forum_admin = User.find_or_initialize_by(email: "forumadmin@krama.com")
forum_admin.assign_attributes(
  first_name: "Fiona", last_name: "Forumadmin", mobile: "9000000002",
  password: "admin123", password_confirmation: "admin123",
  user_type: "forum_admin", forum: forum, status: true
)
forum_admin.save!

mumbai = Chapter.find_or_create_by!(name: "Mumbai Chapter", forum: forum)
pune = Chapter.find_or_create_by!(name: "Pune Chapter", forum: forum)

chapter_admin_mumbai = User.find_or_initialize_by(email: "chapteradmin.mumbai@krama.com")
chapter_admin_mumbai.assign_attributes(
  first_name: "Chetan", last_name: "Mumbai", mobile: "9000000003",
  password: "admin123", password_confirmation: "admin123",
  user_type: "chapter_admin", forum: forum, chapter: mumbai, status: true
)
chapter_admin_mumbai.save!

chapter_admin_pune = User.find_or_initialize_by(email: "chapteradmin.pune@krama.com")
chapter_admin_pune.assign_attributes(
  first_name: "Chitra", last_name: "Pune", mobile: "9000000004",
  password: "admin123", password_confirmation: "admin123",
  user_type: "chapter_admin", forum: forum, chapter: pune, status: true
)
chapter_admin_pune.save!

members = []
[["Manoj", mumbai, "9000000005"], ["Meena", mumbai, "9000000006"], ["Mahesh", pune, "9000000007"]].each do |first, chapter, mobile|
  member = User.find_or_initialize_by(email: "#{first.downcase}@krama.com")
  member.assign_attributes(
    first_name: first, last_name: "Member", mobile: mobile,
    password: "admin123", password_confirmation: "admin123",
    user_type: "member", forum: forum, chapter: chapter, status: true
  )
  member.save!
  members << member
end
puts "Forum '#{forum.name}' with #{forum.chapter_count} chapters and #{forum.member_count} members"
puts "Forum admin: forumadmin@krama.com / admin123"
puts "Chapter admins: chapteradmin.mumbai@krama.com, chapteradmin.pune@krama.com / admin123"
puts "Members: #{members.map(&:email).join(', ')} / admin123"

# --- Announcements at every audience level -----------------------------------
Announcement.find_or_create_by!(title: "Welcome to Krama Consultancy") do |a|
  a.body = "This platform now hosts every business forum we manage. Reach out with questions any time."
  a.audience = :everyone
  a.created_by = super_admin
end
Announcement.find_or_create_by!(title: "Krama Business Network Q3 Kickoff") do |a|
  a.body = "Kicking off Q3 with a renewed focus on referrals across all chapters."
  a.audience = :specific_forum
  a.forum = forum
  a.created_by = forum_admin
end
Announcement.find_or_create_by!(title: "Mumbai Chapter Meeting Moved") do |a|
  a.body = "This week's meeting moves to Thursday 6pm at the usual venue."
  a.audience = :specific_chapter
  a.forum = forum
  a.chapter = mumbai
  a.created_by = chapter_admin_mumbai
end
Announcement.find_or_create_by!(title: "Welcome aboard, Manoj!") do |a|
  a.body = "Great to have you join the Mumbai chapter — see you at the next meeting."
  a.audience = :specific_member
  a.forum = forum
  a.target_user = members.first
  a.created_by = chapter_admin_mumbai
end
puts "Announcements: #{Announcement.count}"

# --- Support Tickets ----------------------------------------------------------
t1 = SupportTicket.find_or_create_by!(subject: "Can't upload profile photo") do |t|
  t.body = "The upload button doesn't respond on my phone."
  t.forum = forum; t.chapter = mumbai; t.raised_by = members.first
  t.status = :open; t.priority = :medium
end
t2 = SupportTicket.find_or_create_by!(subject: "Need an extra chapter for Nagpur") do |t|
  t.body = "We'd like to open a third chapter — what does that involve?"
  t.forum = forum; t.raised_by = forum_admin
  t.status = :in_progress; t.priority = :low
end
t1.replies.find_or_create_by!(user: chapter_admin_mumbai, body: "Could you try on desktop and confirm if it still fails?")
puts "Support tickets: #{SupportTicket.count}"

# --- Events --------------------------------------------------------------------
upcoming = Event.find_or_create_by!(title: "Forum-wide Networking Mixer") do |e|
  e.forum = forum
  e.event_type = :networking
  e.starts_at = 2.weeks.from_now.change(hour: 18)
  e.venue = "Krama Hall, Mumbai"
  e.description = "Open to every chapter — bring a guest!"
end
past = Event.find_or_create_by!(title: "Mumbai Weekly Meeting") do |e|
  e.forum = forum
  e.chapter = mumbai
  e.event_type = :meeting
  e.starts_at = 1.week.ago.change(hour: 9)
  e.venue = "Mumbai Chapter Office"
end
members.select { |m| m.chapter_id == mumbai.id }.each do |m|
  reg = past.event_registrations.find_or_create_by!(user: m)
  reg.update!(attended: true)
end
upcoming.event_registrations.find_or_create_by!(user: members.first)
puts "Events: #{Event.count}, registrations: #{EventRegistration.count}"

puts "== Forum Platform seeding complete =="
