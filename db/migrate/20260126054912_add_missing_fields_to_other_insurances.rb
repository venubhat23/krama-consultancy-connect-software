class AddMissingFieldsToOtherInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :other_insurances, :policy_holder, :string
    add_column :other_insurances, :broker_code_type, :string
    add_column :other_insurances, :agency_code_id, :integer
    add_column :other_insurances, :broker_id, :integer
    add_column :other_insurances, :gst_percentage, :decimal
    add_column :other_insurances, :payment_mode, :string
    add_column :other_insurances, :plan_name, :string
    add_column :other_insurances, :policy_term, :string
    add_column :other_insurances, :claim_process, :string
    add_column :other_insurances, :commission_amount, :decimal
    add_column :other_insurances, :tds_percentage, :decimal
    add_column :other_insurances, :tds_amount, :decimal
    add_column :other_insurances, :after_tds_value, :decimal
    add_column :other_insurances, :sub_agent_commission_percentage, :decimal
    add_column :other_insurances, :sub_agent_commission_amount, :decimal
    add_column :other_insurances, :sub_agent_tds_percentage, :decimal
    add_column :other_insurances, :sub_agent_tds_amount, :decimal
    add_column :other_insurances, :sub_agent_after_tds_value, :decimal
    add_column :other_insurances, :investor_commission_percentage, :decimal
    add_column :other_insurances, :investor_commission_amount, :decimal
    add_column :other_insurances, :investor_tds_percentage, :decimal
    add_column :other_insurances, :investor_tds_amount, :decimal
    add_column :other_insurances, :investor_after_tds_value, :decimal
    add_column :other_insurances, :ambassador_commission_percentage, :decimal
    add_column :other_insurances, :ambassador_commission_amount, :decimal
    add_column :other_insurances, :ambassador_tds_percentage, :decimal
    add_column :other_insurances, :ambassador_tds_amount, :decimal
    add_column :other_insurances, :ambassador_after_tds_value, :decimal
    add_column :other_insurances, :company_expenses_percentage, :decimal
    add_column :other_insurances, :total_distribution_percentage, :decimal
    add_column :other_insurances, :profit_percentage, :decimal
    add_column :other_insurances, :profit_amount, :decimal
    add_column :other_insurances, :installment_autopay_start_date, :date
    add_column :other_insurances, :installment_autopay_end_date, :date
  end
end
