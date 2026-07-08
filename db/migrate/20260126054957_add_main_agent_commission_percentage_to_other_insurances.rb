class AddMainAgentCommissionPercentageToOtherInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :other_insurances, :main_agent_commission_percentage, :decimal
  end
end
