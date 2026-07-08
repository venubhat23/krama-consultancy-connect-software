class AddInvestorIdToInvestorDocumentsSafely < ActiveRecord::Migration[8.0]
  def change
    add_column :investor_documents, :investor_id, :integer unless column_exists?(:investor_documents, :investor_id)
    add_index :investor_documents, :investor_id unless index_exists?(:investor_documents, :investor_id)
  end
end
