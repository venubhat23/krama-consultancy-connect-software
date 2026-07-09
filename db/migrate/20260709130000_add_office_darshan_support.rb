class AddOfficeDarshanSupport < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :created_by_id, :bigint
    add_index :events, :created_by_id

    add_column :event_registrations, :thanked, :boolean, default: false, null: false
    add_column :event_registrations, :thanked_at, :datetime
  end
end
