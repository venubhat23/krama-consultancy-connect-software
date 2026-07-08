class AddR2FieldsToDistributorDocuments < ActiveRecord::Migration[8.0]
  def change
    add_column :distributor_documents, :r2_file_key, :string
    add_column :distributor_documents, :r2_filename, :string
    add_column :distributor_documents, :r2_content_type, :string
    add_column :distributor_documents, :r2_file_size, :bigint
  end
end
