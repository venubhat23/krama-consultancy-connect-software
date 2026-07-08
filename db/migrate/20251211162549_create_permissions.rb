class CreatePermissions < ActiveRecord::Migration[8.0]
  def change
    create_table :permissions do |t|
      t.string :name, null: false, limit: 100
      t.string :module_name, null: false, limit: 50
      t.string :action_type, null: false, limit: 20
      t.text :description

      t.timestamps
    end

    add_index :permissions, [:module_name, :action_type], unique: true
    add_index :permissions, :module_name
    add_index :permissions, :action_type
  end
end
