class CreateCorporateMembers < ActiveRecord::Migration[8.0]
  def change
    create_table :corporate_members do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :company_name
      t.string :mobile
      t.string :email
      t.string :state
      t.string :city
      t.text :address
      t.decimal :annual_income
      t.string :pan_no
      t.string :gst_no
      t.text :additional_information

      t.timestamps
    end
  end
end
