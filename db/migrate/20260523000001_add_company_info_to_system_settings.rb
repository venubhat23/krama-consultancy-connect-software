class AddCompanyInfoToSystemSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :system_settings, :company_name, :string unless column_exists?(:system_settings, :company_name)
    add_column :system_settings, :company_phone, :string unless column_exists?(:system_settings, :company_phone)
    add_column :system_settings, :company_email, :string unless column_exists?(:system_settings, :company_email)
    add_column :system_settings, :company_address, :text unless column_exists?(:system_settings, :company_address)
  end
end
