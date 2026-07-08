class CreateSessionActivities < ActiveRecord::Migration[8.0]
  def change
    create_table :session_activities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :activity_type
      t.datetime :occurred_at
      t.string :ip_address
      t.text :user_agent
      t.string :session_id

      t.timestamps
    end
  end
end
