class AddInstallmentAutopayFieldsToMotorInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :motor_insurances, :installment_autopay_start_date, :date
    add_column :motor_insurances, :installment_autopay_end_date, :date
  end
end
