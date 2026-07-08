class CreatePolicies < ActiveRecord::Migration[8.0]
  def change
    create_table :policies do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :insurance_company, null: false, foreign_key: true
      t.references :agency_broker, null: false, foreign_key: true
      t.string :policy_number
      t.string :policy_type
      t.string :insurance_type
      t.string :plan_name
      t.string :payment_mode
      t.date :policy_booking_date
      t.date :policy_start_date
      t.date :policy_end_date
      t.integer :policy_term_years
      t.date :risk_start_date
      t.decimal :sum_insured
      t.decimal :net_premium
      t.decimal :gst_percentage
      t.decimal :total_premium
      t.decimal :bonus
      t.decimal :fund
      t.text :note
      t.boolean :status

      t.timestamps
    end
  end
end
