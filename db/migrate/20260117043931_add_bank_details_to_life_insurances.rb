class AddBankDetailsToLifeInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :life_insurances, :bank_name, :string unless column_exists?(:life_insurances, :bank_name)
    add_column :life_insurances, :account_type, :string unless column_exists?(:life_insurances, :account_type)
    add_column :life_insurances, :account_number, :string unless column_exists?(:life_insurances, :account_number)
    add_column :life_insurances, :ifsc_code, :string unless column_exists?(:life_insurances, :ifsc_code)
    add_column :life_insurances, :account_holder_name, :string unless column_exists?(:life_insurances, :account_holder_name)
  end
end
