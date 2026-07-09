class Referral < ApplicationRecord
  belongs_to :forum
  belongs_to :chapter, optional: true
  belongs_to :referrer, class_name: "User"
  belongs_to :referred_user, class_name: "User"

  enum :status, { pending: 0, accepted: 1, in_progress: 2, converted: 3, rejected: 4 }

  validates :business_context, presence: true
  validate :referrer_and_referred_user_differ

  before_validation :set_forum_and_chapter, on: :create

  scope :recent_first, -> { order(created_at: :desc) }

  STEPS = [
    [:pending, "Referred"],
    [:accepted, "Accepted"],
    [:in_progress, "In Progress"],
    [:converted, "Converted to Business"]
  ].freeze

  TIMESTAMP_COLUMN_FOR_STEP = {
    pending: :created_at,
    accepted: :accepted_at,
    in_progress: :in_progress_at,
    converted: :converted_at
  }.freeze

  def accept!
    update!(status: :accepted, accepted_at: Time.current)
  end

  def reject!(note = nil)
    update!(status: :rejected, rejected_at: Time.current, rejection_note: note)
  end

  def start_progress!
    update!(status: :in_progress, in_progress_at: Time.current)
  end

  def convert!
    update!(status: :converted, converted_at: Time.current)
  end

  def mark_thanked!(message)
    update!(thanked_at: Time.current, thank_you_message: message)
  end

  def thanked?
    thanked_at.present?
  end

  # Steps up to and including the current status, for a visual stepper.
  def timeline_steps
    return STEPS.first(1) if rejected?

    current_index = STEPS.index { |key, _| key == status.to_sym } || 0
    STEPS.first(current_index + 1)
  end

  private

  def referrer_and_referred_user_differ
    errors.add(:referred_user, "can't be the same as the referrer") if referrer_id.present? && referrer_id == referred_user_id
  end

  def set_forum_and_chapter
    self.forum_id ||= referred_user&.forum_id
    self.chapter_id ||= referred_user&.chapter_id
  end
end
