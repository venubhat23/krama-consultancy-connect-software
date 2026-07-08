class Notification < ApplicationRecord
  # Polymorphic association for recipients
  belongs_to :recipient, polymorphic: true

  # Polymorphic association for the reference object (e.g., ticket, policy, etc.)
  belongs_to :reference, polymorphic: true, optional: true

  # Validations
  validates :recipient_type, presence: true
  validates :recipient_id, presence: true
  validates :notification_type, presence: true
  validates :title, presence: true
  validates :message, presence: true

  # Enums for notification types
  NOTIFICATION_TYPES = %w[
    helpdesk_comment_added
    policy_created
    policy_renewed
    lead_status_updated
    general_announcement
  ].freeze

  # Scopes
  scope :unread, -> { where(is_read: false) }
  scope :read, -> { where(is_read: true) }
  scope :for_sub_agent, ->(sub_agent_id) { where(recipient_type: 'SubAgent', recipient_id: sub_agent_id) }
  scope :for_customer, ->(customer_id) { where(recipient_type: 'Customer', recipient_id: customer_id) }
  scope :recent, -> { order(sent_at: :desc) }

  # Callbacks
  before_create :set_sent_at

  # Instance methods
  def mark_as_read!
    update!(is_read: true, read_at: Time.current)
  end

  def mark_as_unread!
    update!(is_read: false, read_at: nil)
  end

  def read?
    is_read == true
  end

  def unread?
    !read?
  end

  # Class methods
  def self.create_helpdesk_comment_notification(ticket, recipient)
    create!(
      recipient: recipient,
      notification_type: 'helpdesk_comment_added',
      title: 'New Comment on Your Support Ticket',
      message: "An admin has added a comment to your support ticket: #{ticket.subject}",
      reference: ticket,
      is_read: false
    )
  end

  private

  def set_sent_at
    self.sent_at ||= Time.current
  end
end
