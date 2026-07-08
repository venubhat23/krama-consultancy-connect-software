class AddGuestInviteToEventRegistrations < ActiveRecord::Migration[8.0]
  def change
    change_column_null :event_registrations, :user_id, true
    add_column :event_registrations, :guest_name, :string
    add_column :event_registrations, :guest_email, :string
    add_reference :event_registrations, :invited_by, foreign_key: { to_table: :users }
  end
end
