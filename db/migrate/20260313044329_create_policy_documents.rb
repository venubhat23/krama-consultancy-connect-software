class CreatePolicyDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :policy_documents do |t|
      t.string :policy_type, null: false
      t.integer :policy_id, null: false
      t.string :document_type, null: false
      t.string :title, null: false
      t.text :description
      t.string :uploaded_by
      t.string :r2_file_key
      t.string :r2_filename
      t.string :r2_content_type
      t.bigint :r2_file_size

      t.timestamps
    end

    add_index :policy_documents, [:policy_type, :policy_id]
    add_index :policy_documents, :document_type
    add_index :policy_documents, :created_at
  end
end
