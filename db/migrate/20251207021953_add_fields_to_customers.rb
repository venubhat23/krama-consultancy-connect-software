class AddFieldsToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :sub_agent, :string, default: 'Self'
    add_column :customers, :middle_name, :string
    add_column :customers, :height_feet, :string
    add_column :customers, :weight_kg, :decimal, precision: 5, scale: 2
    add_column :customers, :business_job, :string
    add_column :customers, :business_name, :string
    add_column :customers, :additional_information, :text
    add_column :customers, :pan_no, :string
    add_column :customers, :gst_no, :string
  end
end
