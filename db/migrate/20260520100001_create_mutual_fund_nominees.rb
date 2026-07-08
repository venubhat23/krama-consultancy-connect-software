class CreateMutualFundNominees < ActiveRecord::Migration[7.1]
  def change
    create_table :mutual_fund_nominees do |t|
      t.references :mutual_fund, null: false, foreign_key: true
      t.string :nominee_name, null: false
      t.string :relationship
      t.integer :age
      t.decimal :share_percentage, precision: 5, scale: 2

      t.timestamps
    end
  end
end
