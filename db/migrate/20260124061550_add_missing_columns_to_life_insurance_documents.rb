class AddMissingColumnsToLifeInsuranceDocuments < ActiveRecord::Migration[8.0]
  def change
    add_column :life_insurance_documents, :life_insurance_id, :integer unless column_exists?(:life_insurance_documents, :life_insurance_id)
    add_index :life_insurance_documents, :life_insurance_id unless index_exists?(:life_insurance_documents, :life_insurance_id)
    add_column :life_insurance_documents, :document_type, :string unless column_exists?(:life_insurance_documents, :document_type)
    add_column :life_insurance_documents, :document_name, :string unless column_exists?(:life_insurance_documents, :document_name)
  end
end
