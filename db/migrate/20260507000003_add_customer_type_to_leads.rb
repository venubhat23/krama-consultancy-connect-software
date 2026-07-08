class AddCustomerTypeToLeads < ActiveRecord::Migration[8.0]
  def change
    add_column :leads, :customer_type, :string, default: "individual" unless column_exists?(:leads, :customer_type)
  end
end
