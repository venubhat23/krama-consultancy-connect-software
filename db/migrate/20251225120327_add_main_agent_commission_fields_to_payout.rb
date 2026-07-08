class AddMainAgentCommissionFieldsToPayout < ActiveRecord::Migration[8.0]
  def change
    add_column :payouts, :main_agent_commission_received, :boolean
    add_column :payouts, :main_agent_commission_transaction_id, :string
    add_column :payouts, :main_agent_commission_paid_date, :date
  end
end
