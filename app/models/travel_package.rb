class TravelPackage < ApplicationRecord
  belongs_to :customer

  # Validations
  validates :travel_type, presence: true, inclusion: { in: ['Domestic', 'International'] }
  validates :destination, presence: true
  validates :travel_date, presence: true
  validates :package_amount, presence: true, numericality: { greater_than: 0 }

  # Status methods (using boolean column)
  def booked?
    status == true
  end

  def cancelled?
    status == false || status.nil?
  end

  def mark_as_booked!
    update!(status: true)
  end

  def mark_as_cancelled!
    update!(status: false)
  end

  # Scopes
  scope :by_type, ->(type) { where(travel_type: type) }
  scope :upcoming, -> { where('travel_date > ?', Date.current) }
  scope :completed, -> { where('return_date < ?', Date.current) }
  scope :active_bookings, -> { where(status: true) }
  scope :cancelled_bookings, -> { where(status: [false, nil]) }

  # Instance methods
  def display_name
    "#{travel_type} - #{destination}"
  end

  def duration_days
    return 0 unless travel_date && return_date
    (return_date - travel_date).to_i
  end

  def is_upcoming?
    travel_date && travel_date > Date.current
  end

  def is_ongoing?
    travel_date && return_date &&
    Date.current >= travel_date && Date.current <= return_date
  end
end
