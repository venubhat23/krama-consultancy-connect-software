class AddGuestPhoneAndTokenToEventRegistrations < ActiveRecord::Migration[8.0]
  def change
    add_column :event_registrations, :guest_phone, :string
    add_column :event_registrations, :token, :string
    add_index :event_registrations, :token, unique: true
  end
end
