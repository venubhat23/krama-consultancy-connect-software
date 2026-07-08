class AddAdditionalFieldsToLeads < ActiveRecord::Migration[8.0]
  def change
    add_column :leads, :education, :string
    add_column :leads, :business_job, :string
    add_column :leads, :business_name, :string
    add_column :leads, :job_name, :string
    add_column :leads, :occupation, :string
    add_column :leads, :type_of_duty, :string
    add_column :leads, :annual_income, :decimal
    add_column :leads, :additional_information, :text
  end
end
