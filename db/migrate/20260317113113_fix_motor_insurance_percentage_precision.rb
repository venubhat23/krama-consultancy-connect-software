class FixMotorInsurancePercentagePrecision < ActiveRecord::Migration[8.0]
  def change
    change_column :motor_insurances, :main_agent_commission_percentage, :decimal, precision: 8, scale: 2 if column_exists?(:motor_insurances, :main_agent_commission_percentage)
    change_column :motor_insurances, :main_agent_tds_percentage, :decimal, precision: 8, scale: 2 if column_exists?(:motor_insurances, :main_agent_tds_percentage)
    change_column :motor_insurances, :tds_percentage, :decimal, precision: 8, scale: 2 if column_exists?(:motor_insurances, :tds_percentage)
  end
end
