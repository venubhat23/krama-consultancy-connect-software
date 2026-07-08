class AddInsuranceCompanyCodeToAllInsurances < ActiveRecord::Migration[8.0]
  def change
    # Add insurance_company_code to all insurance tables
    add_column :life_insurances, :insurance_company_code, :string
    add_column :health_insurances, :insurance_company_code, :string
    add_column :motor_insurances, :insurance_company_code, :string
    add_column :other_insurances, :insurance_company_code, :string

    # Add indexes for better performance
    add_index :life_insurances, :insurance_company_code
    add_index :health_insurances, :insurance_company_code
    add_index :motor_insurances, :insurance_company_code
    add_index :other_insurances, :insurance_company_code
  end
end
