class ReconcileForumSchemaColumns < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:forums, :business_plan_id)
      add_reference :forums, :business_plan, foreign_key: true
    end

    unless column_exists?(:forum_requests, :business_plan_id)
      add_reference :forum_requests, :business_plan, foreign_key: true
    end

    unless column_exists?(:announcements, :chapter_id)
      add_reference :announcements, :chapter, foreign_key: true
    end
    unless column_exists?(:announcements, :target_user_id)
      add_reference :announcements, :target_user, foreign_key: { to_table: :users }
    end

    unless column_exists?(:support_tickets, :chapter_id)
      add_reference :support_tickets, :chapter, foreign_key: true
    end

    unless column_exists?(:events, :chapter_id)
      add_reference :events, :chapter, foreign_key: true
    end
    unless column_exists?(:events, :description)
      add_column :events, :description, :text
    end

    unless column_exists?(:event_registrations, :attended_at)
      add_column :event_registrations, :attended_at, :datetime
    end
  end
end
