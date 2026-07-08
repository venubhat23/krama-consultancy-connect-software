class AddPolicyAddedByAdminToAllInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :health_insurances, :policy_added_by_admin, :boolean, default: false
    add_column :life_insurances, :policy_added_by_admin, :boolean, default: false
    add_column :motor_insurances, :policy_added_by_admin, :boolean, default: false
  end
end
