class AddMissingColumnsToLifeInsuranceBankDetails < ActiveRecord::Migration[7.0]
  def change
    unless column_exists?(:life_insurance_bank_details, :life_insurance_id)
      add_column :life_insurance_bank_details, :life_insurance_id, :integer
    end
    unless column_exists?(:life_insurance_bank_details, :bank_name)
      add_column :life_insurance_bank_details, :bank_name, :string
    end
    unless column_exists?(:life_insurance_bank_details, :account_type)
      add_column :life_insurance_bank_details, :account_type, :string
    end
    unless column_exists?(:life_insurance_bank_details, :account_number)
      add_column :life_insurance_bank_details, :account_number, :string
    end
    unless column_exists?(:life_insurance_bank_details, :ifsc_code)
      add_column :life_insurance_bank_details, :ifsc_code, :string
    end
    unless column_exists?(:life_insurance_bank_details, :account_holder_name)
      add_column :life_insurance_bank_details, :account_holder_name, :string
    end
    index_name = 'index_life_insurance_bank_details_on_life_insurance_id'
    unless index_exists?(:life_insurance_bank_details, :life_insurance_id, name: index_name)
      add_index :life_insurance_bank_details, :life_insurance_id, name: index_name
    end
  end
end
