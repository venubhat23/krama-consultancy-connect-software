class FixSubAgentDocuments < ActiveRecord::Migration[8.0]
  def change
    # Add sub_agent_id column without foreign key constraint initially
    unless column_exists?(:sub_agent_documents, :sub_agent_id)
      add_column :sub_agent_documents, :sub_agent_id, :integer
      add_index :sub_agent_documents, :sub_agent_id
    end

    # Only add foreign key constraint if the column exists and there are no orphaned records
    if column_exists?(:sub_agent_documents, :sub_agent_id)
      # Clean up any orphaned records first (if any)
      execute "DELETE FROM sub_agent_documents WHERE sub_agent_id IS NOT NULL AND sub_agent_id NOT IN (SELECT id FROM sub_agents)"

      # Add foreign key constraint
      unless foreign_key_exists?(:sub_agent_documents, :sub_agents)
        add_foreign_key :sub_agent_documents, :sub_agents
      end
    end
  end
end
