class CreateReferrals < ActiveRecord::Migration[8.0]
  def change
    create_table :referrals do |t|
      t.references :forum, null: false, foreign_key: true
      t.references :chapter, foreign_key: true
      t.references :referrer, null: false, foreign_key: { to_table: :users }
      t.references :referred_user, null: false, foreign_key: { to_table: :users }
      t.text :business_context, null: false
      t.string :contact_name
      t.string :contact_phone
      t.integer :status, default: 0, null: false
      t.datetime :accepted_at
      t.datetime :in_progress_at
      t.datetime :converted_at
      t.datetime :rejected_at
      t.text :rejection_note
      t.datetime :thanked_at
      t.text :thank_you_message

      t.timestamps
    end
    add_index :referrals, :status
  end
end
