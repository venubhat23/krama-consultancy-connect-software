class CreateMotorInsurances < ActiveRecord::Migration[8.0]
  def change
    create_table :motor_insurances do |t|
      t.references :policy, null: false, foreign_key: true
      t.string :vehicle_type
      t.string :class_of_vehicle
      t.string :registration_number
      t.date :registration_date
      t.string :engine_number
      t.string :chassis_number
      t.integer :mfy
      t.string :make
      t.string :model
      t.string :variant
      t.integer :seating_capacity
      t.decimal :discount_loading_percent
      t.string :previous_policy_number
      t.string :ncb
      t.string :legal_liability
      t.string :electrical_accessories
      t.string :non_electrical_accessories
      t.boolean :zero_depreciation
      t.boolean :roadside_assistance
      t.boolean :engine_protector
      t.boolean :key_replacement
      t.boolean :return_to_invoice
      t.boolean :consumable_cover
      t.boolean :personal_accident_cover
      t.string :financier
      t.decimal :vehicle_idv
      t.decimal :cng_idv
      t.decimal :total_idv
      t.decimal :tp_premium
      t.decimal :payout_od
      t.decimal :payout_tp
      t.decimal :payout_net
      t.decimal :main_agent_commission_percent
      t.decimal :main_agent_commission_amount
      t.decimal :main_agent_tds_percent
      t.decimal :main_agent_tds_amount
      t.string :broker_name

      t.timestamps
    end
  end
end
