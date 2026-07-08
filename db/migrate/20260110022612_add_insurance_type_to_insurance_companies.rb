class AddInsuranceTypeToInsuranceCompanies < ActiveRecord::Migration[8.0]
  def change
    add_column :insurance_companies, :insurance_type, :string
  end
end
