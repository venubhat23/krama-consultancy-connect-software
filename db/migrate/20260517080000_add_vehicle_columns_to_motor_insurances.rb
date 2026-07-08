class AddVehicleColumnsToMotorInsurances < ActiveRecord::Migration[7.0]
  def change
    add_column :motor_insurances, :vehicle_number, :string, limit: 255 unless column_exists?(:motor_insurances, :vehicle_number)
    add_column :motor_insurances, :vehicle_make, :string, limit: 255 unless column_exists?(:motor_insurances, :vehicle_make)
    add_column :motor_insurances, :vehicle_model, :string, limit: 255 unless column_exists?(:motor_insurances, :vehicle_model)
  end
end
