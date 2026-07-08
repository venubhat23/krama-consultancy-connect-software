class CreateAnnouncements < ActiveRecord::Migration[8.0]
  def change
    create_table :announcements do |t|
      t.string :title, null: false
      t.text :body, null: false
      t.integer :audience, default: 0, null: false
      t.references :forum, foreign_key: true
      t.references :chapter, foreign_key: true
      t.references :target_user, foreign_key: { to_table: :users }
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.datetime :published_at

      t.timestamps
    end
    add_index :announcements, :audience
  end
end
