class AddCustomerFieldsToLeads < ActiveRecord::Migration[8.0]
  def change
    add_column :leads, :first_name, :string
    add_column :leads, :middle_name, :string
    add_column :leads, :last_name, :string
    add_column :leads, :birth_date, :date
    add_column :leads, :gender, :string
    add_column :leads, :pan_no, :string
    add_column :leads, :gst_no, :string
    add_column :leads, :company_name, :string
    add_column :leads, :marital_status, :string
  end
end
