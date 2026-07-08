class AddLifeInsuranceIdToLifeInsuranceBankDetails < ActiveRecord::Migration[8.0]
  def change
    add_column :life_insurance_bank_details, :life_insurance_id, :integer unless column_exists?(:life_insurance_bank_details, :life_insurance_id)
    add_index :life_insurance_bank_details, :life_insurance_id unless index_exists?(:life_insurance_bank_details, :life_insurance_id)
  end
end
