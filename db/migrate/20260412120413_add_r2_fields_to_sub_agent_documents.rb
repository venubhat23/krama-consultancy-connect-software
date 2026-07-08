class AddR2FieldsToSubAgentDocuments < ActiveRecord::Migration[8.0]
  def change
    add_column :sub_agent_documents, :r2_file_key, :string
    add_column :sub_agent_documents, :r2_filename, :string
    add_column :sub_agent_documents, :r2_content_type, :string
    add_column :sub_agent_documents, :r2_file_size, :bigint
  end
end
