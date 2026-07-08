class EnsureMotorInsuranceDocumentTables < ActiveRecord::Migration[8.0]
  def change
    # Ensure motor_insurance_documents table exists
    unless table_exists?(:motor_insurance_documents)
      create_table :motor_insurance_documents do |t|
        t.bigint :motor_insurance_id, null: false
        t.string :document_type
        t.string :title
        t.text :description
        t.string :r2_file_key
        t.string :r2_filename
        t.string :r2_content_type
        t.bigint :r2_file_size
        t.string :r2_url
        t.timestamps
      end
      add_index :motor_insurance_documents, :motor_insurance_id, name: 'idx_motor_ins_docs_on_motor_insurance_id'
      add_foreign_key :motor_insurance_documents, :motor_insurances
    else
      add_column :motor_insurance_documents, :r2_url, :string unless column_exists?(:motor_insurance_documents, :r2_url)
    end

    # Ensure main_policy_document R2 columns exist on motor_insurances
    add_column :motor_insurances, :main_policy_document_key, :string unless column_exists?(:motor_insurances, :main_policy_document_key)
    add_column :motor_insurances, :main_policy_document_filename, :string unless column_exists?(:motor_insurances, :main_policy_document_filename)
    add_column :motor_insurances, :main_policy_document_content_type, :string unless column_exists?(:motor_insurances, :main_policy_document_content_type)
    add_column :motor_insurances, :main_policy_document_size, :bigint unless column_exists?(:motor_insurances, :main_policy_document_size)
    add_column :motor_insurances, :main_policy_document_url, :string unless column_exists?(:motor_insurances, :main_policy_document_url)
  end
end
