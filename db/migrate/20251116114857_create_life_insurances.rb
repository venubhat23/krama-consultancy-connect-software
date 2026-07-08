class CreateLifeInsurances < ActiveRecord::Migration[8.0]
  def change
    create_table :life_insurances do |t|
      t.references :policy, null: false, foreign_key: true
      t.string :insured_name
      t.string :nominee_name
      t.string :nominee_relationship
      t.integer :nominee_age
      t.integer :premium_payment_term
      t.decimal :first_year_gst
      t.decimal :second_year_gst
      t.decimal :third_year_gst
      t.decimal :main_agent_commission_percent_first
      t.decimal :main_agent_commission_percent_renewal
      t.decimal :main_agent_commission_amount
      t.decimal :main_agent_tds_percent
      t.decimal :main_agent_tds_amount
      t.string :reference_by_name
      t.string :broker_name

      t.timestamps
    end
  end
end
