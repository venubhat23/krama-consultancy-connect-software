class CreateDistributors < ActiveRecord::Migration[8.0]
  def change
    create_table :distributors do |t|
      t.string :first_name, null: false
      t.string :middle_name
      t.string :last_name, null: false
      t.string :mobile, null: false
      t.string :email, null: false
      t.integer :role_id, null: false
      t.integer :state_id
      t.integer :city_id
      t.date :birth_date
      t.string :gender
      t.string :pan_no
      t.string :gst_no
      t.string :company_name
      t.text :address
      t.string :bank_name
      t.string :account_no
      t.string :ifsc_code
      t.string :account_holder_name
      t.string :account_type
      t.string :upi_id
      t.integer :status, default: 0

      t.timestamps
    end

    add_index :distributors, :mobile, unique: true
    add_index :distributors, :email, unique: true
    add_index :distributors, :role_id
    add_index :distributors, :status
  end
end
