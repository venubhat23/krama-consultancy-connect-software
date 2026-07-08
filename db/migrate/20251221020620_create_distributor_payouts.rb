class CreateDistributorPayouts < ActiveRecord::Migration[8.0]
  def change
    create_table :distributor_payouts do |t|
      t.references :distributor, null: false, foreign_key: true
      t.string :policy_type
      t.integer :policy_id
      t.decimal :payout_amount, precision: 10, scale: 2
      t.date :payout_date
      t.string :status, default: 'pending'
      t.string :transaction_id
      t.string :payment_mode
      t.string :reference_number
      t.text :notes
      t.string :processed_by
      t.datetime :processed_at

      t.timestamps
    end

    add_index :distributor_payouts, [:policy_type, :policy_id]
    add_index :distributor_payouts, [:distributor_id, :status]
    add_index :distributor_payouts, :status
  end
end
