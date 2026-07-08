class EnsureUserTypeColumnOnUsers < ActiveRecord::Migration[8.0]
  def up
    unless column_exists?(:users, :user_type)
      add_column :users, :user_type, :string, limit: 255
    end

    unless index_exists?(:users, :user_type)
      add_index :users, :user_type
    end
  end

  def down
    remove_index :users, :user_type if index_exists?(:users, :user_type)
    remove_column :users, :user_type if column_exists?(:users, :user_type)
  end
end
