class EnhancePayoutWithCommissionDetails < ActiveRecord::Migration[8.0]
  def change
    add_column :payouts, :main_agent_percentage, :decimal, precision: 8, scale: 2
    add_column :payouts, :main_agent_commission_amount, :decimal, precision: 10, scale: 2
    add_column :payouts, :main_agent_commission_id, :integer

    add_column :payouts, :affiliate_percentage, :decimal, precision: 8, scale: 2
    add_column :payouts, :affiliate_commission_amount, :decimal, precision: 10, scale: 2
    add_column :payouts, :affiliate_commission_id, :integer

    add_column :payouts, :ambassador_percentage, :decimal, precision: 8, scale: 2
    add_column :payouts, :ambassador_commission_amount, :decimal, precision: 10, scale: 2
    add_column :payouts, :ambassador_commission_id, :integer

    add_column :payouts, :investor_percentage, :decimal, precision: 8, scale: 2
    add_column :payouts, :investor_commission_amount, :decimal, precision: 10, scale: 2
    add_column :payouts, :investor_commission_id, :integer

    add_column :payouts, :company_expense_percentage, :decimal, precision: 8, scale: 2
    add_column :payouts, :company_expense_amount, :decimal, precision: 10, scale: 2
    add_column :payouts, :company_expense_commission_id, :integer

    add_column :payouts, :commission_summary, :text

    add_index :payouts, :main_agent_commission_id
    add_index :payouts, :affiliate_commission_id
    add_index :payouts, :ambassador_commission_id
    add_index :payouts, :investor_commission_id
    add_index :payouts, :company_expense_commission_id
  end
end
