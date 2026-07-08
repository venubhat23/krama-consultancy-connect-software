class EventRegistration < ApplicationRecord
  belongs_to :event
  belongs_to :user

  validates :user_id, uniqueness: { scope: :event_id }

  before_save :stamp_attended_at

  private

  def stamp_attended_at
    self.attended_at = (attended? ? (attended_at || Time.current) : nil)
  end
end
