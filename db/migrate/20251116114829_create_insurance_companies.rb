class CreateInsuranceCompanies < ActiveRecord::Migration[8.0]
  def change
    create_table :insurance_companies do |t|
      t.string :name
      t.boolean :status

      t.timestamps
    end
  end
end
