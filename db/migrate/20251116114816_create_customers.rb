class CreateCustomers < ActiveRecord::Migration[8.0]
  def change
    create_table :customers do |t|
      t.string :customer_type
      t.string :first_name
      t.string :last_name
      t.string :company_name
      t.string :email
      t.string :mobile
      t.string :address
      t.string :state
      t.string :city
      t.date :birth_date
      t.integer :age
      t.string :gender
      t.string :height
      t.string :weight
      t.string :education
      t.string :marital_status
      t.string :occupation
      t.string :job_name
      t.string :type_of_duty
      t.decimal :annual_income
      t.string :pan_number
      t.string :gst_number
      t.string :birth_place
      t.text :additional_info
      t.boolean :status
      t.string :added_by

      t.timestamps
    end
  end
end
