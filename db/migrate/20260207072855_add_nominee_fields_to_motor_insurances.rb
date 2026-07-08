class AddNomineeFieldsToMotorInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :motor_insurances, :nominee_name, :string
    add_column :motor_insurances, :nominee_relation, :string
    add_column :motor_insurances, :nominee_dob, :date
  end
end
