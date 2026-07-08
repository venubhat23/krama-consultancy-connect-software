class CreateForumRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :forum_requests do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone
      t.string :company_name, null: false
      t.text :message
      t.integer :status, default: 0, null: false
      t.text :review_note
      t.references :business_plan, foreign_key: true
      t.references :forum, foreign_key: true
      t.references :reviewed_by, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
