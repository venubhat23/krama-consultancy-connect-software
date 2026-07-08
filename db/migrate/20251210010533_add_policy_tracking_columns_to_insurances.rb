class AddPolicyTrackingColumnsToInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :health_insurances, :is_customer_added, :boolean, default: false
    add_column :health_insurances, :is_agent_added, :boolean, default: false
    add_column :health_insurances, :is_admin_added, :boolean, default: false

    add_column :life_insurances, :is_customer_added, :boolean, default: false
    add_column :life_insurances, :is_agent_added, :boolean, default: false
    add_column :life_insurances, :is_admin_added, :boolean, default: false
  end
end
