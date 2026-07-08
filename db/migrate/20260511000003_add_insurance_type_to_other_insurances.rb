class AddInsuranceTypeToOtherInsurances < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:other_insurances, :insurance_type)
      add_column :other_insurances, :insurance_type, :string, limit: 255
    end
  end
end
