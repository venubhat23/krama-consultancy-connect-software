class CreateCustomerDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :customer_documents do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :document_type

      t.timestamps
    end
  end
end
