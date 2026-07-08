class AddInvestmentAmountToSystemSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :system_settings, :investment_amount, :decimal, precision: 15, scale: 2, default: 0.0
  end
end
