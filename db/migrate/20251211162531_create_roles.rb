class CreateRoles < ActiveRecord::Migration[8.0]
  def change
    create_table :roles do |t|
      t.string :name, null: false, limit: 100
      t.text :description
      t.boolean :status, default: true, null: false

      t.timestamps
    end

    add_index :roles, :name, unique: true
    add_index :roles, :status
  end
end
