class AddSidebarPermissionsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :sidebar_permissions, :text
  end
end
