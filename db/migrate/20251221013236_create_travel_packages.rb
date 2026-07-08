class CreateTravelPackages < ActiveRecord::Migration[8.0]
  def change
    create_table :travel_packages do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :travel_type
      t.string :destination
      t.date :travel_date
      t.date :return_date
      t.decimal :package_amount
      t.boolean :status
      t.text :notes

      t.timestamps
    end
  end
end
