class AddSumInsuredToMotorInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :motor_insurances, :sum_insured, :decimal
  end
end
