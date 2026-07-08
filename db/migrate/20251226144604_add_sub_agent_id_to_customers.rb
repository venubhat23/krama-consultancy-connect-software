class AddSubAgentIdToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :sub_agent_id, :integer
    add_index :customers, :sub_agent_id
    add_foreign_key :customers, :sub_agents, column: :sub_agent_id
  end
end
