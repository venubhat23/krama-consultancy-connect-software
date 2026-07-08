class AddPaymentModeToMotorInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :motor_insurances, :payment_mode, :string
  end
end
