class AddIndexesToOptimizeCommissionTracking < ActiveRecord::Migration[8.0]
  def change
    # Add indexes for commission tracking performance
    add_index :payouts, [:policy_type, :policy_id], name: 'index_payouts_on_policy_type_and_id'
    add_index :payouts, [:created_at], name: 'index_payouts_on_created_at'
    add_index :payouts, [:status], name: 'index_payouts_on_status'
    add_index :payouts, [:payout_to], name: 'index_payouts_on_payout_to' if column_exists?(:payouts, :payout_to)

    # Add indexes for insurance policy lookups
    add_index :life_insurances, [:customer_id], name: 'index_life_insurances_on_customer_id' unless index_exists?(:life_insurances, :customer_id)
    add_index :health_insurances, [:customer_id], name: 'index_health_insurances_on_customer_id' if table_exists?(:health_insurances) && !index_exists?(:health_insurances, :customer_id)
    add_index :motor_insurances, [:customer_id], name: 'index_motor_insurances_on_customer_id' if table_exists?(:motor_insurances) && !index_exists?(:motor_insurances, :customer_id)

    # Add indexes for commission payouts
    if table_exists?(:commission_payouts) && !index_exists?(:commission_payouts, [:payout_to, :status])
      add_index :commission_payouts, [:payout_to, :status], name: 'index_commission_payouts_on_payout_to_and_status'
    end
  end
end
