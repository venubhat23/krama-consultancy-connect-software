class CreateTaxServices < ActiveRecord::Migration[8.0]
  def change
    create_table :tax_services do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :service_type
      t.string :financial_year
      t.date :filing_date
      t.decimal :amount
      t.boolean :status
      t.text :notes

      t.timestamps
    end
  end
end
