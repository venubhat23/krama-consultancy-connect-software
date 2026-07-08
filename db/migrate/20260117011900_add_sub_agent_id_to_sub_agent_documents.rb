class AddSubAgentIdToSubAgentDocuments < ActiveRecord::Migration[8.0]
  def change
    add_reference :sub_agent_documents, :sub_agent, null: false, foreign_key: true unless column_exists?(:sub_agent_documents, :sub_agent_id)
    add_column :sub_agent_documents, :document_type, :string unless column_exists?(:sub_agent_documents, :document_type)

    # Add index for better performance
    add_index :sub_agent_documents, :document_type unless index_exists?(:sub_agent_documents, :document_type)
  end
end
