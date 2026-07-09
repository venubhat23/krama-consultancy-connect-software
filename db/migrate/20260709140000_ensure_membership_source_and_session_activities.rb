class EnsureMembershipSourceAndSessionActivities < ActiveRecord::Migration[8.0]
  def up
    unless column_exists?(:membership_applications, :source)
      add_column :membership_applications, :source, :integer, null: false, default: 0
    end

    unless table_exists?(:session_activities)
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

  def down
    remove_column :membership_applications, :source if column_exists?(:membership_applications, :source)
    drop_table :session_activities if table_exists?(:session_activities)
  end
end
