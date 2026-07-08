class EnsureHealthInsuranceDocumentsTable < ActiveRecord::Migration[8.0]
  def up
    return if table_exists?(:health_insurance_documents)

    create_table :health_insurance_documents do |t|
      t.references :health_insurance, null: false, foreign_key: true
      t.string :document_type
      t.string :title
      t.text :description
      t.string :r2_file_key
      t.string :r2_filename
      t.string :r2_content_type
      t.bigint :r2_file_size

      t.timestamps
    end
  end

  def down
    drop_table :health_insurance_documents, if_exists: true
  end
end
