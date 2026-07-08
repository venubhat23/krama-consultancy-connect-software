class AddRoleToUsers < ActiveRecord::Migration[8.0]
  def change
    add_reference :users, :role, null: true, foreign_key: true
    add_index :users, :role_id, name: 'idx_users_role_id'
  end
end
