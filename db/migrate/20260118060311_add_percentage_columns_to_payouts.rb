class AddPercentageColumnsToPayouts < ActiveRecord::Migration[8.0]
  def change
    add_column :payouts, :main_agent_percentage, :decimal unless column_exists?(:payouts, :main_agent_percentage)
    add_column :payouts, :affiliate_percentage, :decimal unless column_exists?(:payouts, :affiliate_percentage)
    add_column :payouts, :ambassador_percentage, :decimal unless column_exists?(:payouts, :ambassador_percentage)
    add_column :payouts, :investor_percentage, :decimal unless column_exists?(:payouts, :investor_percentage)
    add_column :payouts, :company_expense_percentage, :decimal unless column_exists?(:payouts, :company_expense_percentage)
  end
end
