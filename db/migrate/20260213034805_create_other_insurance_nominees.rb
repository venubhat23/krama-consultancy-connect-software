class CreateOtherInsuranceNominees < ActiveRecord::Migration[8.0]
  def change
    create_table :other_insurance_nominees do |t|
      t.references :other_insurance, null: false, foreign_key: true
      t.string :nominee_name
      t.string :relationship
      t.integer :age
      t.decimal :share_percentage

      t.timestamps
    end
  end
end
