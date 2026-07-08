class CreateCommissionPayouts < ActiveRecord::Migration[8.0]
  def change
    create_table :commission_payouts do |t|
      t.string :policy_type
      t.integer :policy_id
      t.string :payout_to
      t.decimal :payout_amount
      t.date :payout_date
      t.string :status

      t.timestamps
    end
  end
end
