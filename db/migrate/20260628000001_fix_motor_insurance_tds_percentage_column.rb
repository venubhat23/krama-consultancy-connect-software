class FixMotorInsuranceTdsPercentageColumn < ActiveRecord::Migration[8.0]
  def change
    if column_exists?(:motor_insurances, :main_agent_tds_percent) && !column_exists?(:motor_insurances, :main_agent_tds_percentage)
      rename_column :motor_insurances, :main_agent_tds_percent, :main_agent_tds_percentage
    elsif !column_exists?(:motor_insurances, :main_agent_tds_percentage)
      add_column :motor_insurances, :main_agent_tds_percentage, :decimal, precision: 8, scale: 2
    end
  end
end
