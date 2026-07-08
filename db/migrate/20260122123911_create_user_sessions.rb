class CreateUserSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :user_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :session_id, null: false
      t.string :ip_address
      t.text :user_agent
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.integer :duration
      t.string :status, default: 'active'
      t.string :location
      t.string :device_type
      t.string :browser

      t.timestamps
    end

    add_index :user_sessions, :session_id, unique: true
    add_index :user_sessions, :started_at
    add_index :user_sessions, :status
    add_index :user_sessions, :ip_address
  end
end
