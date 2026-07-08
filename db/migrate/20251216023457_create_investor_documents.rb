class CreateInvestorDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :investor_documents do |t|
      t.references :investor, null: false, foreign_key: true
      t.string :document_type

      t.timestamps
    end
  end
end
