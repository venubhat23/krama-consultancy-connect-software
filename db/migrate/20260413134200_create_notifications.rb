class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.string :recipient_type
      t.integer :recipient_id
      t.string :notification_type
      t.string :title
      t.text :message
      t.string :reference_type
      t.integer :reference_id
      t.boolean :is_read
      t.datetime :sent_at
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, [:recipient_type, :recipient_id]
    add_index :notifications, [:reference_type, :reference_id]
    add_index :notifications, :is_read
    add_index :notifications, :sent_at
  end
end
