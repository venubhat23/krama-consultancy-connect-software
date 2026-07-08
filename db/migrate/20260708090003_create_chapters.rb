class CreateChapters < ActiveRecord::Migration[8.0]
  def change
    create_table :chapters do |t|
      t.references :forum, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :status, default: 0, null: false

      t.timestamps
    end
    add_index :chapters, [:forum_id, :name], unique: true
  end
end
