class AddR2FieldsToSubAgentDocumentsFixed < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:sub_agent_documents, :r2_file_key)
      add_column :sub_agent_documents, :r2_file_key, :string
    end
    unless column_exists?(:sub_agent_documents, :r2_filename)
      add_column :sub_agent_documents, :r2_filename, :string
    end
    unless column_exists?(:sub_agent_documents, :r2_content_type)
      add_column :sub_agent_documents, :r2_content_type, :string
    end
    unless column_exists?(:sub_agent_documents, :r2_file_size)
      add_column :sub_agent_documents, :r2_file_size, :bigint
    end
  end
end
