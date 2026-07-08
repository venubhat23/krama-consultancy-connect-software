class AddFieldsToHealthInsurances < ActiveRecord::Migration[8.0]
  def change
    # Check if columns exist before adding
    unless column_exists?(:health_insurances, :customer_id)
      add_reference :health_insurances, :customer, null: true, foreign_key: true
    end

    unless column_exists?(:health_insurances, :sub_agent_id)
      add_reference :health_insurances, :sub_agent, null: true, foreign_key: true
    end

    unless column_exists?(:health_insurances, :agency_code_id)
      add_reference :health_insurances, :agency_code, null: true, foreign_key: true
    end

    unless column_exists?(:health_insurances, :broker_id)
      add_reference :health_insurances, :broker, null: true, foreign_key: true
    end

    add_column :health_insurances, :policy_holder, :string unless column_exists?(:health_insurances, :policy_holder)
    add_column :health_insurances, :insurance_company_name, :string unless column_exists?(:health_insurances, :insurance_company_name)
    add_column :health_insurances, :plan_name, :string unless column_exists?(:health_insurances, :plan_name)
    add_column :health_insurances, :policy_number, :string unless column_exists?(:health_insurances, :policy_number)
    add_column :health_insurances, :policy_booking_date, :date unless column_exists?(:health_insurances, :policy_booking_date)
    add_column :health_insurances, :policy_start_date, :date unless column_exists?(:health_insurances, :policy_start_date)
    add_column :health_insurances, :policy_end_date, :date unless column_exists?(:health_insurances, :policy_end_date)
    add_column :health_insurances, :policy_term, :integer unless column_exists?(:health_insurances, :policy_term)
    add_column :health_insurances, :payment_mode, :string unless column_exists?(:health_insurances, :payment_mode)
    add_column :health_insurances, :sum_insured, :decimal unless column_exists?(:health_insurances, :sum_insured)
    add_column :health_insurances, :net_premium, :decimal unless column_exists?(:health_insurances, :net_premium)
    add_column :health_insurances, :gst_percentage, :decimal unless column_exists?(:health_insurances, :gst_percentage)
    add_column :health_insurances, :total_premium, :decimal unless column_exists?(:health_insurances, :total_premium)
    add_column :health_insurances, :main_agent_commission_percentage, :decimal unless column_exists?(:health_insurances, :main_agent_commission_percentage)
    add_column :health_insurances, :commission_amount, :decimal unless column_exists?(:health_insurances, :commission_amount)
    add_column :health_insurances, :tds_percentage, :decimal unless column_exists?(:health_insurances, :tds_percentage)
    add_column :health_insurances, :tds_amount, :decimal unless column_exists?(:health_insurances, :tds_amount)
    add_column :health_insurances, :after_tds_value, :decimal unless column_exists?(:health_insurances, :after_tds_value)

    # Skip reference_by_name if it already exists
    unless column_exists?(:health_insurances, :reference_by_name)
      add_column :health_insurances, :reference_by_name, :string
    end

    add_column :health_insurances, :policy_type, :string unless column_exists?(:health_insurances, :policy_type)
    add_column :health_insurances, :insurance_type, :string unless column_exists?(:health_insurances, :insurance_type)
    add_column :health_insurances, :claim_process, :text unless column_exists?(:health_insurances, :claim_process)
  end
end
