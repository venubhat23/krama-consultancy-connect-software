class AddTrackingColumnsToLifeInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :life_insurances, :is_customer_added, :boolean, default: false unless column_exists?(:life_insurances, :is_customer_added)
    add_column :life_insurances, :is_agent_added, :boolean, default: false unless column_exists?(:life_insurances, :is_agent_added)
    add_column :life_insurances, :is_admin_added, :boolean, default: false unless column_exists?(:life_insurances, :is_admin_added)
    add_column :life_insurances, :policy_added_by_admin, :boolean, default: false unless column_exists?(:life_insurances, :policy_added_by_admin)
  end
end
