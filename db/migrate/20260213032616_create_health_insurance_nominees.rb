class CreateHealthInsuranceNominees < ActiveRecord::Migration[8.0]
  def change
    create_table :health_insurance_nominees do |t|
      t.references :health_insurance, null: false, foreign_key: true
      t.string :nominee_name
      t.string :relationship
      t.integer :age
      t.decimal :share_percentage

      t.timestamps
    end
  end
end
