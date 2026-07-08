class AddCriticalDashboardIndexes < ActiveRecord::Migration[8.0]
  def change
    # Helper method to check if column exists
    def column_exists?(table, column)
      connection.column_exists?(table, column)
    end

    # Critical indexes for product_through_dr filtering (only for tables that have this column)
    if column_exists?(:health_insurances, :product_through_dr)
      add_index :health_insurances, :product_through_dr unless index_exists?(:health_insurances, :product_through_dr)
      add_index :health_insurances, [:product_through_dr, :created_at] unless index_exists?(:health_insurances, [:product_through_dr, :created_at])
      add_index :health_insurances, [:product_through_dr, :total_premium] unless index_exists?(:health_insurances, [:product_through_dr, :total_premium])
      add_index :health_insurances, [:product_through_dr, :sum_insured] unless index_exists?(:health_insurances, [:product_through_dr, :sum_insured])
    end

    if column_exists?(:life_insurances, :product_through_dr)
      add_index :life_insurances, :product_through_dr unless index_exists?(:life_insurances, :product_through_dr)
      add_index :life_insurances, [:product_through_dr, :created_at] unless index_exists?(:life_insurances, [:product_through_dr, :created_at])
      add_index :life_insurances, [:product_through_dr, :total_premium] unless index_exists?(:life_insurances, [:product_through_dr, :total_premium])
      add_index :life_insurances, [:product_through_dr, :sum_insured] unless index_exists?(:life_insurances, [:product_through_dr, :sum_insured])
    end

    # For motor and other insurances, only add created_at indexes since they don't have product_through_dr
    if table_exists?(:motor_insurances)
      add_index :motor_insurances, :created_at unless index_exists?(:motor_insurances, :created_at)
      add_index :motor_insurances, :sub_agent_id unless index_exists?(:motor_insurances, :sub_agent_id)
    end

    if table_exists?(:other_insurances)
      add_index :other_insurances, :created_at unless index_exists?(:other_insurances, :created_at)
    end

    # Critical indexes for affiliate calculation
    add_index :health_insurances, :sub_agent_id unless index_exists?(:health_insurances, :sub_agent_id)
    add_index :life_insurances, :sub_agent_id unless index_exists?(:life_insurances, :sub_agent_id)
  end
end
