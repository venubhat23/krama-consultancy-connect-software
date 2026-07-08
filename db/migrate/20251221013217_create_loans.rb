class CreateLoans < ActiveRecord::Migration[8.0]
  def change
    create_table :loans do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :loan_type
      t.decimal :loan_amount
      t.decimal :interest_rate
      t.integer :loan_term
      t.decimal :emi_amount
      t.date :loan_date
      t.boolean :status
      t.text :notes

      t.timestamps
    end
  end
end
