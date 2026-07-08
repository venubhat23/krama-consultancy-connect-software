class EventRegistration < ApplicationRecord
  belongs_to :event
  belongs_to :user

  enum :rsvp_status, { going: 0, not_going: 1 }

  validates :user_id, uniqueness: { scope: :event_id }

  before_save :stamp_attended_at

  private

  def stamp_attended_at
    self.attended_at = (attended? ? (attended_at || Time.current) : nil)
  end
end
