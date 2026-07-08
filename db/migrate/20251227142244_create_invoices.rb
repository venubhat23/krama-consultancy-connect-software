class CreateInvoices < ActiveRecord::Migration[8.0]
  def change
    create_table :invoices do |t|
      t.string :invoice_number, null: false
      t.string :payout_type, null: false
      t.integer :payout_id, null: false
      t.decimal :total_amount, precision: 10, scale: 2, null: false
      t.string :status, null: false, default: 'pending'
      t.date :invoice_date, null: false
      t.date :due_date, null: false
      t.datetime :paid_at
      t.string :recipient_name
      t.string :recipient_email
      t.text :recipient_address
      t.text :notes

      t.timestamps
    end

    add_index :invoices, :invoice_number, unique: true
    add_index :invoices, [:payout_type, :payout_id]
    add_index :invoices, :status
    add_index :invoices, :invoice_date
  end
end
