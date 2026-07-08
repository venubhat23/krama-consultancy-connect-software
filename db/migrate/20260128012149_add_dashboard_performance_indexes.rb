class AddDashboardPerformanceIndexes < ActiveRecord::Migration[6.1]
  def change
    # Indexes for Customer queries
    add_index :customers, :status unless index_exists?(:customers, :status)
    add_index :customers, :created_at unless index_exists?(:customers, :created_at)
    add_index :customers, [:status, :created_at] unless index_exists?(:customers, [:status, :created_at])

    # Indexes for SubAgent queries
    add_index :sub_agents, :status unless index_exists?(:sub_agents, :status)
    add_index :sub_agents, :created_at unless index_exists?(:sub_agents, :created_at)

    # Indexes for Lead queries
    add_index :leads, :current_stage unless index_exists?(:leads, :current_stage)
    add_index :leads, :created_at unless index_exists?(:leads, :created_at)
    add_index :leads, [:current_stage, :created_at] unless index_exists?(:leads, [:current_stage, :created_at])

    # Indexes for Health Insurance queries
    add_index :health_insurances, :policy_end_date unless index_exists?(:health_insurances, :policy_end_date)
    add_index :health_insurances, :created_at unless index_exists?(:health_insurances, :created_at)
    add_index :health_insurances, :policy_type unless index_exists?(:health_insurances, :policy_type)
    add_index :health_insurances, [:policy_end_date, :created_at] unless index_exists?(:health_insurances, [:policy_end_date, :created_at])
    add_index :health_insurances, [:customer_id, :created_at] unless index_exists?(:health_insurances, [:customer_id, :created_at])

    # Indexes for Life Insurance queries
    add_index :life_insurances, :policy_end_date unless index_exists?(:life_insurances, :policy_end_date)
    add_index :life_insurances, :created_at unless index_exists?(:life_insurances, :created_at)
    add_index :life_insurances, :policy_type unless index_exists?(:life_insurances, :policy_type)
    add_index :life_insurances, [:policy_end_date, :created_at] unless index_exists?(:life_insurances, [:policy_end_date, :created_at])
    add_index :life_insurances, [:customer_id, :created_at] unless index_exists?(:life_insurances, [:customer_id, :created_at])

    # Indexes for Motor Insurance queries (if table exists)
    if table_exists?(:motor_insurances)
      add_index :motor_insurances, :policy_end_date unless index_exists?(:motor_insurances, :policy_end_date)
      add_index :motor_insurances, :created_at unless index_exists?(:motor_insurances, :created_at)
      add_index :motor_insurances, :policy_type unless index_exists?(:motor_insurances, :policy_type)
      add_index :motor_insurances, [:policy_end_date, :created_at] unless index_exists?(:motor_insurances, [:policy_end_date, :created_at])
      add_index :motor_insurances, [:customer_id, :created_at] unless index_exists?(:motor_insurances, [:customer_id, :created_at])
    end

    # Indexes for Other Insurance queries (if table exists)
    if table_exists?(:other_insurances)
      add_index :other_insurances, :policy_end_date unless index_exists?(:other_insurances, :policy_end_date)
      add_index :other_insurances, :created_at unless index_exists?(:other_insurances, :created_at)
      add_index :other_insurances, [:policy_end_date, :created_at] unless index_exists?(:other_insurances, [:policy_end_date, :created_at])
      add_index :other_insurances, [:customer_id, :created_at] unless index_exists?(:other_insurances, [:customer_id, :created_at]) || !column_exists?(:other_insurances, :customer_id)
    end

    # Indexes for Commission Payout queries
    add_index :commission_payouts, :status unless index_exists?(:commission_payouts, :status)
    add_index :commission_payouts, :created_at unless index_exists?(:commission_payouts, :created_at)
    add_index :commission_payouts, [:status, :created_at] unless index_exists?(:commission_payouts, [:status, :created_at])
    add_index :commission_payouts, [:policy_type, :policy_id] unless index_exists?(:commission_payouts, [:policy_type, :policy_id])

    # Indexes for Distributor queries
    add_index :distributors, :created_at unless index_exists?(:distributors, :created_at)

    # Indexes for Distributor Payout queries (if table exists)
    if table_exists?(:distributor_payouts)
      add_index :distributor_payouts, :status unless index_exists?(:distributor_payouts, :status)
      add_index :distributor_payouts, :created_at unless index_exists?(:distributor_payouts, :created_at)
      add_index :distributor_payouts, [:status, :created_at] unless index_exists?(:distributor_payouts, [:status, :created_at])
    end
  end
end