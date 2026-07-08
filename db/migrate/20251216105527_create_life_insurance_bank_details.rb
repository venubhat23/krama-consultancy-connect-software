class CreateLifeInsuranceBankDetails < ActiveRecord::Migration[8.0]
  def change
    create_table :life_insurance_bank_details do |t|
      t.references :life_insurance, null: false, foreign_key: true
      t.string :bank_name
      t.string :account_type
      t.string :account_number
      t.string :ifsc_code
      t.string :account_holder_name

      t.timestamps
    end
  end
end
