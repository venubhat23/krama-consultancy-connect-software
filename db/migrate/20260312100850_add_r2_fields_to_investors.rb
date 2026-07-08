class AddR2FieldsToInvestors < ActiveRecord::Migration[8.0]
  def change
    add_column :investors, :main_document_key, :string
    add_column :investors, :main_document_filename, :string
    add_column :investors, :main_document_content_type, :string
    add_column :investors, :main_document_size, :bigint
  end
end
