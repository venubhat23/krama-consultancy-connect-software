class AddClassOfVehicleToMotorInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :motor_insurances, :class_of_vehicle, :string unless column_exists?(:motor_insurances, :class_of_vehicle)
  end
end
