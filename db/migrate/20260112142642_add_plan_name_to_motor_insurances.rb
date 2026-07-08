class AddPlanNameToMotorInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :motor_insurances, :plan_name, :string
  end
end
