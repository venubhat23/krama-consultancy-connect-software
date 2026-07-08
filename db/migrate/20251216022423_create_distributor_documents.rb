class CreateDistributorDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :distributor_documents do |t|
      t.references :distributor, null: false, foreign_key: true
      t.string :document_type

      t.timestamps
    end
  end
end
