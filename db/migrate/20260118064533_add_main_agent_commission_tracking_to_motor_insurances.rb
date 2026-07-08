class AddMainAgentCommissionTrackingToMotorInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :motor_insurances, :main_agent_commission_received, :boolean unless column_exists?(:motor_insurances, :main_agent_commission_received)
    add_column :motor_insurances, :main_agent_commission_transaction_id, :string unless column_exists?(:motor_insurances, :main_agent_commission_transaction_id)
    add_column :motor_insurances, :main_agent_commission_paid_date, :date unless column_exists?(:motor_insurances, :main_agent_commission_paid_date)
    add_column :motor_insurances, :main_agent_commission_notes, :text unless column_exists?(:motor_insurances, :main_agent_commission_notes)
  end
end
