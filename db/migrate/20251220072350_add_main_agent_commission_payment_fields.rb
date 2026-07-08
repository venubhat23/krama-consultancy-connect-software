class AddMainAgentCommissionPaymentFields < ActiveRecord::Migration[8.0]
  def change
    add_column :health_insurances, :main_agent_commission_received, :boolean, default: false
    add_column :health_insurances, :main_agent_commission_transaction_id, :string
    add_column :health_insurances, :main_agent_commission_paid_date, :date
    add_column :health_insurances, :main_agent_commission_notes, :text

    add_column :life_insurances, :main_agent_commission_received, :boolean, default: false
    add_column :life_insurances, :main_agent_commission_transaction_id, :string
    add_column :life_insurances, :main_agent_commission_paid_date, :date
    add_column :life_insurances, :main_agent_commission_notes, :text

    add_column :motor_insurances, :main_agent_commission_received, :boolean, default: false
    add_column :motor_insurances, :main_agent_commission_transaction_id, :string
    add_column :motor_insurances, :main_agent_commission_paid_date, :date
    add_column :motor_insurances, :main_agent_commission_notes, :text

    add_column :other_insurances, :main_agent_commission_received, :boolean, default: false
    add_column :other_insurances, :main_agent_commission_transaction_id, :string
    add_column :other_insurances, :main_agent_commission_paid_date, :date
    add_column :other_insurances, :main_agent_commission_notes, :text
  end
end
