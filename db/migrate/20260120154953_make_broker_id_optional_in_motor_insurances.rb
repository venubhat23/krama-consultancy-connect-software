class MakeBrokerIdOptionalInMotorInsurances < ActiveRecord::Migration[8.0]
  def change
    change_column_null :motor_insurances, :broker_id, true
  end
end
