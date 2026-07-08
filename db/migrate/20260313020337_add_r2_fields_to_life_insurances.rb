class AddR2FieldsToLifeInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :life_insurances, :main_policy_document_key, :string
    add_column :life_insurances, :main_policy_document_filename, :string
    add_column :life_insurances, :main_policy_document_content_type, :string
    add_column :life_insurances, :main_policy_document_size, :bigint
  end
end
