class CreateHealthInsuranceMembers < ActiveRecord::Migration[8.0]
  def change
    create_table :health_insurance_members do |t|
      t.references :health_insurance, null: false, foreign_key: true
      t.string :member_name
      t.integer :age
      t.string :relationship
      t.decimal :sum_insured

      t.timestamps
    end
  end
end
