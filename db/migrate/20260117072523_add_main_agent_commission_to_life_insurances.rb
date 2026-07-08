class AddMainAgentCommissionToLifeInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :life_insurances, :main_agent_commission_percentage, :decimal unless column_exists?(:life_insurances, :main_agent_commission_percentage)
    add_column :life_insurances, :commission_amount, :decimal unless column_exists?(:life_insurances, :commission_amount)
    add_column :life_insurances, :tds_percentage, :decimal unless column_exists?(:life_insurances, :tds_percentage)
  end
end
