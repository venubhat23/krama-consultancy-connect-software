class AddTotalCommissionAmountToCommissionPayouts < ActiveRecord::Migration[8.0]
  def change
    add_column :commission_payouts, :total_commission_amount, :decimal, precision: 10, scale: 2

    # Populate the new column with existing payout_amount values
    reversible do |dir|
      dir.up do
        execute "UPDATE commission_payouts SET total_commission_amount = payout_amount WHERE total_commission_amount IS NULL"
      end
    end
  end
end
