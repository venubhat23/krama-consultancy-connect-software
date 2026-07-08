class AddMissingColumnsToCommissionPayoutsAndOtherInsurances < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:commission_payouts, :tds_amount)
      add_column :commission_payouts, :tds_amount, :decimal, precision: 10, scale: 2
    end

    unless column_exists?(:other_insurances, :customer_id)
      add_column :other_insurances, :customer_id, :bigint
      add_index :other_insurances, [:customer_id, :created_at],
                name: 'index_other_insurances_on_customer_id_and_created_at',
                if_not_exists: true
    end
  end
end
