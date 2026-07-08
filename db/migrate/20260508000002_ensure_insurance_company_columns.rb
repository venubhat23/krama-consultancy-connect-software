class EnsureInsuranceCompanyColumns < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:insurance_companies, :insurance_type)
      add_column :insurance_companies, :insurance_type, :string
    end
  end
end
