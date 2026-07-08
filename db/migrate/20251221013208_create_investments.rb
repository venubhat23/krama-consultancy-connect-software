class CreateInvestments < ActiveRecord::Migration[8.0]
  def change
    create_table :investments do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :investment_type
      t.string :product_name
      t.decimal :investment_amount
      t.boolean :status
      t.date :investment_date
      t.date :maturity_date
      t.text :notes

      t.timestamps
    end
  end
end
