class AddAmbassadorCommissionToHealthInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :health_insurances, :ambassador_commission_percentage, :decimal
    add_column :health_insurances, :ambassador_commission_amount, :decimal
    add_column :health_insurances, :ambassador_tds_percentage, :decimal
    add_column :health_insurances, :ambassador_tds_amount, :decimal
    add_column :health_insurances, :ambassador_after_tds_value, :decimal
    add_column :health_insurances, :sub_agent_commission_percentage, :decimal
    add_column :health_insurances, :sub_agent_commission_amount, :decimal
    add_column :health_insurances, :sub_agent_tds_percentage, :decimal
    add_column :health_insurances, :sub_agent_tds_amount, :decimal
    add_column :health_insurances, :sub_agent_after_tds_value, :decimal
    add_column :health_insurances, :investor_commission_percentage, :decimal
    add_column :health_insurances, :investor_commission_amount, :decimal
    add_column :health_insurances, :investor_tds_percentage, :decimal
    add_column :health_insurances, :investor_tds_amount, :decimal
    add_column :health_insurances, :investor_after_tds_value, :decimal
    add_column :health_insurances, :company_expenses_percentage, :decimal
    add_column :health_insurances, :total_distribution_percentage, :decimal
    add_column :health_insurances, :profit_percentage, :decimal
    add_column :health_insurances, :profit_amount, :decimal
  end
end
