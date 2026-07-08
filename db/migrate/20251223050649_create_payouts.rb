class CreatePayouts < ActiveRecord::Migration[8.0]
  def change
    create_table :payouts do |t|
      t.string :policy_type
      t.integer :policy_id
      t.integer :customer_id
      t.decimal :total_commission_amount
      t.string :status
      t.date :payout_date
      t.string :processed_by
      t.datetime :processed_at
      t.text :notes
      t.string :reference_number

      t.timestamps
    end
  end
end
