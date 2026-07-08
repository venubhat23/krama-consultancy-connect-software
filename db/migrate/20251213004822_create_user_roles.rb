class CreateUserRoles < ActiveRecord::Migration[8.0]
  def change
    create_table :user_roles do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :status, default: true, null: false
      t.integer :display_order, default: 0, null: false

      t.timestamps
    end

    add_index :user_roles, :name, unique: true
    add_index :user_roles, :display_order
    add_index :user_roles, :status

    # Add some default user roles
    reversible do |dir|
      dir.up do
        UserRole.create!([
          { name: 'Admin', description: 'Administrator with full system access', status: true, display_order: 1 },
          { name: 'Agent', description: 'Insurance agent with customer management access', status: true, display_order: 2 },
          { name: 'Sub Agent', description: 'Sub agent with limited access', status: true, display_order: 3 },
          { name: 'Manager', description: 'Manager with team oversight capabilities', status: true, display_order: 4 },
          { name: 'Support', description: 'Support staff with helpdesk access', status: true, display_order: 5 }
        ])
      end
    end
  end
end
