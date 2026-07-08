class AddCommissionFieldsToLifeInsurances < ActiveRecord::Migration[8.0]
  def change
    add_reference :life_insurances, :distributor, null: true, foreign_key: true
    add_reference :life_insurances, :investor, null: true, foreign_key: true
    add_column :life_insurances, :sub_agent_commission_percentage, :decimal, precision: 5, scale: 2, default: 2.0
    add_column :life_insurances, :sub_agent_commission_amount, :decimal, precision: 10, scale: 2
    add_column :life_insurances, :distributor_commission_percentage, :decimal, precision: 5, scale: 2, default: 1.0
    add_column :life_insurances, :distributor_commission_amount, :decimal, precision: 10, scale: 2
    add_column :life_insurances, :investor_commission_percentage, :decimal, precision: 5, scale: 2, default: 2.0
    add_column :life_insurances, :investor_commission_amount, :decimal, precision: 10, scale: 2
    add_column :life_insurances, :main_income_percentage, :decimal, precision: 5, scale: 2, default: 10.0
    add_column :life_insurances, :main_income_amount, :decimal, precision: 10, scale: 2
    add_column :life_insurances, :total_distribution_percentage, :decimal, precision: 5, scale: 2
    add_column :life_insurances, :company_expenses_percentage, :decimal, precision: 5, scale: 2
    add_column :life_insurances, :profit_percentage, :decimal, precision: 5, scale: 2
    add_column :life_insurances, :profit_amount, :decimal, precision: 10, scale: 2
    add_column :life_insurances, :sub_agent_tds_percentage, :decimal, precision: 5, scale: 2, default: 0.0
    add_column :life_insurances, :sub_agent_tds_amount, :decimal, precision: 10, scale: 2
    add_column :life_insurances, :sub_agent_after_tds_value, :decimal, precision: 10, scale: 2
    add_column :life_insurances, :distributor_tds_percentage, :decimal, precision: 5, scale: 2, default: 0.0
    add_column :life_insurances, :distributor_tds_amount, :decimal, precision: 10, scale: 2
    add_column :life_insurances, :distributor_after_tds_value, :decimal, precision: 10, scale: 2
    add_column :life_insurances, :investor_tds_percentage, :decimal, precision: 5, scale: 2, default: 0.0
    add_column :life_insurances, :investor_tds_amount, :decimal, precision: 10, scale: 2
    add_column :life_insurances, :investor_after_tds_value, :decimal, precision: 10, scale: 2
  end
end
