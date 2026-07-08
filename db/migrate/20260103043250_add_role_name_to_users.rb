class AddRoleNameToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :role_name, :string
  end
end
