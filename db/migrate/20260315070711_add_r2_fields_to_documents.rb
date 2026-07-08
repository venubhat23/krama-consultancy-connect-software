class AddR2FieldsToDocuments < ActiveRecord::Migration[8.0]
  def change
    add_column :documents, :r2_file_key, :string
    add_column :documents, :r2_filename, :string
    add_column :documents, :r2_content_type, :string
    add_column :documents, :r2_file_size, :bigint
  end
end
