class AddMissingColumnsToOtherInsurances < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:other_insurances, :sum_insured)
      add_column :other_insurances, :sum_insured, :decimal, precision: 15, scale: 2
    end
    unless column_exists?(:other_insurances, :insurance_company_name)
      add_column :other_insurances, :insurance_company_name, :string, limit: 255
    end
  end
end
