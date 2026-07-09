class MembershipApplication < ApplicationRecord
  belongs_to :forum
  belongs_to :chapter, optional: true
  belongs_to :event, optional: true
  belongs_to :invited_by, class_name: "User", optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true
  belongs_to :user, optional: true

  has_many_attached :kyc_documents

  enum :status, {
    invited: 0, confirmed: 1, attended: 2, feedback_collected: 3, interested: 4,
    kyc_submitted: 5, under_review: 6, approved: 7, paid: 8, member: 9, rejected: 10
  }
  enum :source, { event_invite: 0, direct_invite: 1 }

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token, presence: true, uniqueness: true

  before_validation :generate_token, on: :create
  before_validation :set_source, on: :create

  scope :active, -> { where.not(status: [:member, :rejected]) }
  scope :recent_first, -> { order(created_at: :desc) }

  EVENT_STEPS = [
    [:invited, "Invited"],
    [:confirmed, "Confirmed"],
    [:attended, "Attended"],
    [:feedback_collected, "Feedback Collected"],
    [:interested, "Invited to Join"],
    [:kyc_submitted, "KYC Submitted"],
    [:under_review, "Under Review"],
    [:approved, "Approved"],
    [:paid, "Paid"],
    [:member, "Member"]
  ].freeze

  DIRECT_STEPS = [
    [:invited, "Invited"],
    [:interested, "Interest Confirmed"],
    [:kyc_submitted, "KYC Submitted"],
    [:under_review, "Under Review"],
    [:approved, "Approved"],
    [:paid, "Paid"],
    [:member, "Member"]
  ].freeze

  TIMESTAMP_COLUMN_FOR_STEP = {
    invited: :created_at,
    confirmed: :confirmed_at,
    attended: :attended_at,
    feedback_collected: :feedback_collected_at,
    interested: :interested_at,
    kyc_submitted: :kyc_submitted_at,
    under_review: :review_started_at,
    approved: :approved_at,
    paid: :paid_at,
    member: :member_since_at
  }.freeze

  def event_led?
    event_id.present?
  end

  # Ordered list of {key:, label:, completed_at:, current:} for the guest's actual path.
  def timeline_steps
    steps = event_led? ? EVENT_STEPS : DIRECT_STEPS
    reached = rejected? ? steps.index { |key, _| key == status_before_rejection } : steps.index { |key, _| key.to_s == status }
    steps.each_with_index.map do |(key, label), i|
      {
        key: key,
        label: label,
        completed_at: step_completed_at(key),
        current: reached && i == reached
      }
    end
  end

  # The event flow never sets interested_at (KYC submission itself is the guest's
  # confirmation), so its "Invited to Join" step reads join_invite_sent_at instead.
  def step_completed_at(key)
    if key == :interested && event_led?
      join_invite_sent_at
    else
      public_send(TIMESTAMP_COLUMN_FOR_STEP[key])
    end
  end

  # Best-effort: the stage the application had reached before it was rejected.
  def status_before_rejection
    TIMESTAMP_COLUMN_FOR_STEP.keys.reverse.find { |k| k != :member && public_send(TIMESTAMP_COLUMN_FOR_STEP[k]).present? } || :invited
  end

  def confirm_rsvp!
    update!(status: :confirmed, confirmed_at: Time.current)
  end

  def mark_attended!
    update!(status: :attended, attended_at: Time.current)
  end

  def record_feedback!(rating: nil, comment: nil)
    update!(status: :feedback_collected, feedback_collected_at: Time.current, feedback_rating: rating, feedback_comment: comment)
  end

  def send_join_invite!
    update!(join_invite_sent_at: Time.current)
  end

  def confirm_interest!
    update!(status: :interested, interested_at: Time.current)
  end

  def submit_kyc!(attrs, documents: nil)
    assign_attributes(attrs)
    self.status = :kyc_submitted
    self.kyc_submitted_at = Time.current
    kyc_documents.attach(documents) if documents.present?
    save!
  end

  def start_review!
    update!(status: :under_review, review_started_at: Time.current)
  end

  def approve!(reviewer:, payment_instructions: nil)
    update!(status: :approved, approved_at: Time.current, reviewed_by: reviewer, payment_instructions: payment_instructions)
  end

  def reject!(reviewer:, note:)
    update!(status: :rejected, rejected_at: Time.current, reviewed_by: reviewer, review_note: note)
  end

  def mark_paid!
    update!(status: :paid, paid_at: Time.current)
  end

  # Creates the member User account and links it back to this application.
  # Returns the generated temporary password (not persisted anywhere) so the
  # admin can hand it to the new member.
  def convert_to_member!
    temp_password = SecureRandom.hex(6)
    new_user = nil

    transaction do
      first, *rest = name.split(" ")
      new_user = User.create!(
        first_name: first,
        last_name: rest.join(" ").presence || first,
        email: email,
        mobile: phone,
        user_type: "member",
        forum: forum,
        chapter: chapter,
        status: true,
        password: temp_password,
        password_confirmation: temp_password
      )
      update!(status: :member, member_since_at: Time.current, user: new_user)
    end

    temp_password
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(24)
  end

  def set_source
    self.source ||= event_id.present? ? :event_invite : :direct_invite
  end
end
