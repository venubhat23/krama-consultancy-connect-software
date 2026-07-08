class AddPolicyNumberToMotorInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :motor_insurances, :policy_number, :string
    add_index :motor_insurances, :policy_number, unique: true
  end
end
