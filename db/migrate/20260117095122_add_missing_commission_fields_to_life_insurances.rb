class AddMissingCommissionFieldsToLifeInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :life_insurances, :tds_amount, :decimal unless column_exists?(:life_insurances, :tds_amount)
    add_column :life_insurances, :after_tds_value, :decimal unless column_exists?(:life_insurances, :after_tds_value)
    add_column :life_insurances, :sub_agent_commission_percentage, :decimal unless column_exists?(:life_insurances, :sub_agent_commission_percentage)
    add_column :life_insurances, :sub_agent_commission_amount, :decimal unless column_exists?(:life_insurances, :sub_agent_commission_amount)
    add_column :life_insurances, :sub_agent_tds_percentage, :decimal unless column_exists?(:life_insurances, :sub_agent_tds_percentage)
    add_column :life_insurances, :sub_agent_tds_amount, :decimal unless column_exists?(:life_insurances, :sub_agent_tds_amount)
    add_column :life_insurances, :sub_agent_after_tds_value, :decimal unless column_exists?(:life_insurances, :sub_agent_after_tds_value)
    add_column :life_insurances, :investor_commission_percentage, :decimal unless column_exists?(:life_insurances, :investor_commission_percentage)
    add_column :life_insurances, :investor_commission_amount, :decimal unless column_exists?(:life_insurances, :investor_commission_amount)
    add_column :life_insurances, :investor_tds_percentage, :decimal unless column_exists?(:life_insurances, :investor_tds_percentage)
    add_column :life_insurances, :investor_tds_amount, :decimal unless column_exists?(:life_insurances, :investor_tds_amount)
    add_column :life_insurances, :investor_after_tds_value, :decimal unless column_exists?(:life_insurances, :investor_after_tds_value)
  end
end
