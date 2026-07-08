class FixAddR2FieldsToLifeInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :life_insurances, :main_policy_document_key, :string unless column_exists?(:life_insurances, :main_policy_document_key)
    add_column :life_insurances, :main_policy_document_filename, :string unless column_exists?(:life_insurances, :main_policy_document_filename)
    add_column :life_insurances, :main_policy_document_content_type, :string unless column_exists?(:life_insurances, :main_policy_document_content_type)
    add_column :life_insurances, :main_policy_document_size, :bigint unless column_exists?(:life_insurances, :main_policy_document_size)
  end
end
