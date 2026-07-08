class AddStatusToMotorInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :motor_insurances, :status, :boolean
  end
end
