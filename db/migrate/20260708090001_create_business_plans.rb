class CreateBusinessPlans < ActiveRecord::Migration[8.0]
  def change
    create_table :business_plans do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.decimal :price, precision: 10, scale: 2, default: "0.0", null: false
      t.integer :chapter_limit
      t.integer :member_limit
      t.text :description
      t.boolean :active, default: true, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end
    add_index :business_plans, :key, unique: true
  end
end
