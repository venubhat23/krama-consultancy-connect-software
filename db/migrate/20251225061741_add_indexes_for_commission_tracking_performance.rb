class AddIndexesForCommissionTrackingPerformance < ActiveRecord::Migration[8.0]
  def change
    # Indexes for commission_payouts table
    add_index :commission_payouts, [:policy_type, :policy_id], name: 'idx_commission_payouts_policy'
    add_index :commission_payouts, [:policy_type, :policy_id, :status], name: 'idx_commission_payouts_policy_status'
    add_index :commission_payouts, :status, name: 'idx_commission_payouts_status'

    # Indexes for payouts table
    add_index :payouts, [:policy_type, :policy_id], name: 'idx_payouts_policy'

    # Indexes for insurance tables (created_at for ordering)
    add_index :health_insurances, :created_at, name: 'idx_health_insurances_created_at'
    add_index :life_insurances, :created_at, name: 'idx_life_insurances_created_at'
    add_index :motor_insurances, :created_at, name: 'idx_motor_insurances_created_at' if table_exists?(:motor_insurances)
    add_index :other_insurances, :created_at, name: 'idx_other_insurances_created_at' if table_exists?(:other_insurances)

    # Composite indexes for common queries
    add_index :commission_payouts, [:payout_to, :status], name: 'idx_commission_payouts_payout_to_status'
  end
end
