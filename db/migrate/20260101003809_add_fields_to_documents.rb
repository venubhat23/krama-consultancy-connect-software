class AddFieldsToDocuments < ActiveRecord::Migration[8.0]
  def change
    add_column :documents, :title, :string
    add_column :documents, :description, :text
    add_column :documents, :uploaded_by, :string
  end
end
