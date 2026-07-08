class CreateLeads < ActiveRecord::Migration[8.0]
  def change
    create_table :leads do |t|
      t.string :name
      t.string :contact_number
      t.string :email
      t.string :referred_by
      t.string :product_interest
      t.string :current_stage
      t.date :created_date
      t.text :note

      t.timestamps
    end
  end
end
