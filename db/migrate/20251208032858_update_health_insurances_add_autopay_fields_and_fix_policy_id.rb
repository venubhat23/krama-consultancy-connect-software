class UpdateHealthInsurancesAddAutopayFieldsAndFixPolicyId < ActiveRecord::Migration[8.0]
  def change
    # Make policy_id nullable since it seems to be unused
    change_column_null :health_insurances, :policy_id, true

    # Add autopay installment fields
    add_column :health_insurances, :installment_autopay_start_date, :date
    add_column :health_insurances, :installment_autopay_end_date, :date
  end
end
