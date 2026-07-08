class CreateSubAgentDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :sub_agent_documents do |t|
      t.references :sub_agent, null: false, foreign_key: true
      t.string :document_type, null: false

      t.timestamps
    end

    add_index :sub_agent_documents, [:sub_agent_id, :document_type]
  end
end
