class AddDefaultCommissionToSystemSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :system_settings, :default_main_agent_commission, :decimal, precision: 5, scale: 2
    add_column :system_settings, :default_affiliate_commission, :decimal, precision: 5, scale: 2
    add_column :system_settings, :default_ambassador_commission, :decimal, precision: 5, scale: 2
    add_column :system_settings, :default_company_expenses, :decimal, precision: 5, scale: 2
  end
end
