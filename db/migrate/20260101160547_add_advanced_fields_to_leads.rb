class AddAdvancedFieldsToLeads < ActiveRecord::Migration[8.0]
  def change
    # Only add columns that don't exist yet
    add_column :leads, :birth_place, :string unless column_exists?(:leads, :birth_place)
    add_column :leads, :height_feet, :decimal, precision: 3, scale: 1 unless column_exists?(:leads, :height_feet)
    add_column :leads, :weight_kg, :decimal, precision: 5, scale: 1 unless column_exists?(:leads, :weight_kg)
    add_column :leads, :education, :string unless column_exists?(:leads, :education)
    add_column :leads, :business_job_type, :string unless column_exists?(:leads, :business_job_type)
    add_column :leads, :business_job_name, :string unless column_exists?(:leads, :business_job_name)
    add_column :leads, :job_name, :string unless column_exists?(:leads, :job_name)
    add_column :leads, :occupation, :string unless column_exists?(:leads, :occupation)
    add_column :leads, :duty_type, :string unless column_exists?(:leads, :duty_type)
    add_column :leads, :annual_income, :decimal, precision: 15, scale: 2 unless column_exists?(:leads, :annual_income)
    add_column :leads, :additional_information, :text unless column_exists?(:leads, :additional_information)
  end
end
