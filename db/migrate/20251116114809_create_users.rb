class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :mobile
      t.string :pan_number
      t.string :gst_number
      t.date :date_of_birth
      t.string :gender
      t.string :height
      t.string :weight
      t.string :education
      t.string :marital_status
      t.string :occupation
      t.string :job_name
      t.string :type_of_duty
      t.decimal :annual_income
      t.string :birth_place
      t.string :address
      t.string :state
      t.string :city
      t.string :user_type
      t.string :role
      t.boolean :status
      t.text :additional_info

      t.timestamps
    end
  end
end
