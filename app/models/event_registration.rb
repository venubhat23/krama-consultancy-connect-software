class EventRegistration < ApplicationRecord
  belongs_to :event
  belongs_to :user, optional: true
  belongs_to :invited_by, class_name: "User", optional: true

  enum :rsvp_status, { going: 0, not_going: 1, invited: 2 }

  validates :user_id, uniqueness: { scope: :event_id }, allow_nil: true
  validates :guest_name, presence: true, if: -> { user_id.blank? }
  validate :user_or_guest_present

  before_validation :generate_token, on: :create, if: :guest?
  before_save :stamp_attended_at

  def guest?
    user_id.blank?
  end

  def display_name
    user&.full_name || guest_name
  end

  def thank!
    update!(thanked: true, thanked_at: Time.current)
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(24)
  end

  def user_or_guest_present
    return if user_id.present? || guest_name.present?
    errors.add(:base, "Registration needs either a member or a guest name")
  end

  def stamp_attended_at
    self.attended_at = (attended? ? (attended_at || Time.current) : nil)
  end
end
