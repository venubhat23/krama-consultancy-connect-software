class AddBankDetailsToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :bank_name, :string
    add_column :customers, :account_no, :string
    add_column :customers, :ifsc_code, :string
  end
end
