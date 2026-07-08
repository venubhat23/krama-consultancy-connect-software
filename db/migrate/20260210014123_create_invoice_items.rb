class CreateInvoiceItems < ActiveRecord::Migration[8.0]
  def change
    create_table :invoice_items do |t|
      t.references :invoice, null: false, foreign_key: true
      t.string :payout_type
      t.integer :payout_id
      t.string :description
      t.decimal :amount

      t.timestamps
    end
  end
end
