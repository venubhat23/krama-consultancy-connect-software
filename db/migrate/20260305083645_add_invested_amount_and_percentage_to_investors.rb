class AddInvestedAmountAndPercentageToInvestors < ActiveRecord::Migration[8.0]
  def change
    add_column :investors, :invested_amount, :decimal
    add_column :investors, :investment_percentage, :decimal
  end
end
