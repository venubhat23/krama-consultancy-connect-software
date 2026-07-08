class AddNetPremiumToPayouts < ActiveRecord::Migration[8.0]
  def change
    add_column :payouts, :net_premium, :decimal
  end
end
