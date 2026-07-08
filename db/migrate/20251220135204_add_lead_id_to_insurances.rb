class AddLeadIdToInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :health_insurances, :lead_id, :string
    add_column :life_insurances, :lead_id, :string
    add_column :motor_insurances, :lead_id, :string
    add_column :other_insurances, :lead_id, :string

    add_index :health_insurances, :lead_id, unique: true
    add_index :life_insurances, :lead_id, unique: true
    add_index :motor_insurances, :lead_id, unique: true
    add_index :other_insurances, :lead_id, unique: true
  end
end
