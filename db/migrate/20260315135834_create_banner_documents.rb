class CreateBannerDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :banner_documents do |t|
      t.references :banner, null: false, foreign_key: true
      t.string :document_type
      t.string :title
      t.text :description
      t.string :r2_file_key
      t.string :r2_filename
      t.string :r2_content_type
      t.bigint :r2_file_size
      t.string :uploaded_by

      t.timestamps
    end
  end
end
