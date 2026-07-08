class AddMissingColumnsToLifeInsuranceNominees < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:life_insurance_nominees, :life_insurance_id)
      add_column :life_insurance_nominees, :life_insurance_id, :integer, null: false
      add_index :life_insurance_nominees, :life_insurance_id
      add_foreign_key :life_insurance_nominees, :life_insurances, column: :life_insurance_id
    end
    add_column :life_insurance_nominees, :nominee_name, :string, null: false unless column_exists?(:life_insurance_nominees, :nominee_name)
    add_column :life_insurance_nominees, :relationship, :string, null: false unless column_exists?(:life_insurance_nominees, :relationship)
    add_column :life_insurance_nominees, :age, :integer unless column_exists?(:life_insurance_nominees, :age)
    add_column :life_insurance_nominees, :share_percentage, :decimal, precision: 5, scale: 2 unless column_exists?(:life_insurance_nominees, :share_percentage)
  end
end
