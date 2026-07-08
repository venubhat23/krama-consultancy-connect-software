class CreateLifeInsuranceDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :life_insurance_documents do |t|
      t.references :life_insurance, null: false, foreign_key: true
      t.string :document_type
      t.string :document_name

      t.timestamps
    end
  end
end
