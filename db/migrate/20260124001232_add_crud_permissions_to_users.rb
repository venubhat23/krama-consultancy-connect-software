class AddCrudPermissionsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :crud_permissions, :text
  end
end
