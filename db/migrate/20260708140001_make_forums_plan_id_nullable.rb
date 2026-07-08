class MakeForumsPlanIdNullable < ActiveRecord::Migration[8.0]
  def up
    change_column_null :forums, :plan_id, true if column_exists?(:forums, :plan_id)
  end

  def down
    # Irreversible: we don't know what value to backfill.
  end
end
