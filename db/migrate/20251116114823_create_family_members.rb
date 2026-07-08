class CreateFamilyMembers < ActiveRecord::Migration[8.0]
  def change
    create_table :family_members do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :name
      t.date :birth_date
      t.integer :age
      t.string :height
      t.string :weight
      t.string :gender
      t.string :relationship
      t.string :pan_number
      t.string :mobile

      t.timestamps
    end
  end
end
