class AddMissingFieldsToMotorInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :motor_insurances, :insurance_company_name, :string
    add_column :motor_insurances, :policy_holder, :string
    add_column :motor_insurances, :policy_type, :string
    add_column :motor_insurances, :gst_percentage, :decimal, precision: 8, scale: 2, default: 18.0
    add_column :motor_insurances, :net_premium, :decimal, precision: 10, scale: 2
    add_column :motor_insurances, :gst_amount, :decimal, precision: 10, scale: 2
    add_column :motor_insurances, :after_tds_value, :decimal, precision: 10, scale: 2
    add_column :motor_insurances, :is_customer_added, :boolean, default: false
    add_column :motor_insurances, :is_agent_added, :boolean, default: false
    add_column :motor_insurances, :is_admin_added, :boolean, default: false
    add_column :motor_insurances, :reference_by_name, :string
    add_column :motor_insurances, :extra_note, :text

    # Add customer_id column for direct association
    add_reference :motor_insurances, :customer, null: false, foreign_key: true
    add_reference :motor_insurances, :sub_agent, foreign_key: true
    add_reference :motor_insurances, :agency_code, foreign_key: true
    add_reference :motor_insurances, :broker, foreign_key: true

    # Add additional motor-specific fields
    add_column :motor_insurances, :insurance_type, :string
    add_column :motor_insurances, :total_premium, :decimal, precision: 10, scale: 2
  end
end
