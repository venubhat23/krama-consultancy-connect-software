class AddRsvpStatusToEventRegistrations < ActiveRecord::Migration[8.0]
  def change
    add_column :event_registrations, :rsvp_status, :integer, default: 0, null: false
    add_index :event_registrations, :rsvp_status
  end
end
