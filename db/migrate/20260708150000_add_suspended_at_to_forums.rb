class AddSuspendedAtToForums < ActiveRecord::Migration[8.0]
  def change
    add_column :forums, :suspended_at, :datetime unless column_exists?(:forums, :suspended_at)
  end
end
