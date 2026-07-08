class CreateMotorInsuranceDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :motor_insurance_documents do |t|
      t.references :motor_insurance, null: false, foreign_key: true
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
end
