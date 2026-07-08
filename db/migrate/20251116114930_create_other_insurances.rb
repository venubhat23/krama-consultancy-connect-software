class CreateOtherInsurances < ActiveRecord::Migration[8.0]
  def change
    create_table :other_insurances do |t|
      t.references :policy, null: false, foreign_key: true
      t.string :other_policy_type
      t.decimal :main_agent_commission_percent
      t.decimal :main_agent_commission_amount
      t.decimal :main_agent_tds_percent
      t.decimal :main_agent_tds_amount
      t.string :reference_by_name
      t.string :broker_name

      t.timestamps
    end
  end
end
