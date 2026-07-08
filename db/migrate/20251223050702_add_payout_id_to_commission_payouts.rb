class AddPayoutIdToCommissionPayouts < ActiveRecord::Migration[8.0]
  def change
    add_reference :commission_payouts, :payout, null: true, foreign_key: true
  end
end
