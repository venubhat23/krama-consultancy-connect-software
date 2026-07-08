class CreateAppointments < ActiveRecord::Migration[8.0]
  def change
    create_table :appointments do |t|
      t.references :customer, null: true, foreign_key: true
      t.string :customer_name, null: false
      t.string :customer_email
      t.string :customer_phone
      t.text :meeting_agenda
      t.text :notes
      t.date :appointment_date, null: false
      t.string :time_slot, null: false
      t.string :status, default: 'pending', null: false
      t.references :created_by, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :appointments, :appointment_date
    add_index :appointments, :status
  end
end
