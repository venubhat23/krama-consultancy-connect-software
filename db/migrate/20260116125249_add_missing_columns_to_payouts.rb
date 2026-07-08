class AddMissingColumnsToPayouts < ActiveRecord::Migration[8.0]
  def up
    add_column :payouts, :main_agent_commission_amount, :decimal, precision: 10, scale: 2, default: 0.0 unless column_exists?(:payouts, :main_agent_commission_amount)
    add_column :payouts, :affiliate_commission_amount, :decimal, precision: 10, scale: 2, default: 0.0 unless column_exists?(:payouts, :affiliate_commission_amount)
    add_column :payouts, :ambassador_commission_amount, :decimal, precision: 10, scale: 2, default: 0.0 unless column_exists?(:payouts, :ambassador_commission_amount)
    add_column :payouts, :investor_commission_amount, :decimal, precision: 10, scale: 2, default: 0.0 unless column_exists?(:payouts, :investor_commission_amount)
    add_column :payouts, :company_expense_amount, :decimal, precision: 10, scale: 2, default: 0.0 unless column_exists?(:payouts, :company_expense_amount)

    # Update existing records to have default values
    execute <<-SQL
      UPDATE payouts SET
        main_agent_commission_amount = 0.0,
        affiliate_commission_amount = 0.0,
        ambassador_commission_amount = 0.0,
        investor_commission_amount = 0.0,
        company_expense_amount = 0.0
      WHERE main_agent_commission_amount IS NULL;
    SQL
  end

  def down
    remove_column :payouts, :company_expense_amount if column_exists?(:payouts, :company_expense_amount)
    remove_column :payouts, :investor_commission_amount if column_exists?(:payouts, :investor_commission_amount)
    remove_column :payouts, :ambassador_commission_amount if column_exists?(:payouts, :ambassador_commission_amount)
    remove_column :payouts, :affiliate_commission_amount if column_exists?(:payouts, :affiliate_commission_amount)
    remove_column :payouts, :main_agent_commission_amount if column_exists?(:payouts, :main_agent_commission_amount)
  end
end
