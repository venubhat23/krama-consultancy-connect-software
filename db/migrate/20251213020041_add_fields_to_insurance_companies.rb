class AddFieldsToInsuranceCompanies < ActiveRecord::Migration[8.0]
  def change
    add_column :insurance_companies, :code, :string
    add_column :insurance_companies, :contact_person, :string
    add_column :insurance_companies, :email, :string
    add_column :insurance_companies, :mobile, :string
    add_column :insurance_companies, :address, :text
  end
end
