class CreateMembershipApplications < ActiveRecord::Migration[7.1]
  def change
    create_table :membership_applications do |t|
      t.references :forum, null: false, foreign_key: true
      t.references :chapter, foreign_key: true
      t.references :event, foreign_key: true
      t.references :invited_by, foreign_key: { to_table: :users }
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.references :user, foreign_key: true

      t.string :name, null: false
      t.string :email, null: false
      t.string :phone
      t.string :company_name
      t.string :designation
      t.string :pan_number
      t.string :gst_number
      t.text :business_address

      t.integer :source, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.string :token, null: false

      t.text :payment_instructions
      t.text :review_note
      t.integer :feedback_rating
      t.text :feedback_comment

      t.datetime :confirmed_at
      t.datetime :attended_at
      t.datetime :feedback_collected_at
      t.datetime :join_invite_sent_at
      t.datetime :interested_at
      t.datetime :kyc_submitted_at
      t.datetime :review_started_at
      t.datetime :approved_at
      t.datetime :rejected_at
      t.datetime :paid_at
      t.datetime :member_since_at

      t.timestamps
    end

    add_index :membership_applications, :token, unique: true
    add_index :membership_applications, :status
  end
end
