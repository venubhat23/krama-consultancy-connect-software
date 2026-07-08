class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :events do |t|
      t.references :forum, null: false, foreign_key: true
      t.references :chapter, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.integer :event_type, default: 0, null: false
      t.datetime :starts_at, null: false
      t.string :venue

      t.timestamps
    end

    create_table :event_registrations do |t|
      t.references :event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.boolean :attended, default: false, null: false
      t.datetime :attended_at

      t.timestamps
    end
    add_index :event_registrations, [:event_id, :user_id], unique: true
  end
end
