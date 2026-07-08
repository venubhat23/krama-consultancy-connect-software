class CreateForums < ActiveRecord::Migration[8.0]
  def change
    create_table :forums do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.references :business_plan, null: false, foreign_key: true
      t.integer :status, default: 0, null: false
      t.datetime :suspended_at

      t.timestamps
    end
    add_index :forums, :slug, unique: true
  end
end
