class RemovePolicyFromMotorInsurances < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :motor_insurances, :policies
    remove_column :motor_insurances, :policy_id, :bigint
    remove_index :motor_insurances, :policy_id if index_exists?(:motor_insurances, :policy_id)
  end
end
