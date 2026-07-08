class AddLeadIdToMotorInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :motor_insurances, :lead_id, :string unless column_exists?(:motor_insurances, :lead_id)
    add_index :motor_insurances, :lead_id, unique: true unless index_exists?(:motor_insurances, :lead_id)
  end
end
