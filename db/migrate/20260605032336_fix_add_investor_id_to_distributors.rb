class FixAddInvestorIdToDistributors < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:distributors, :investor_id)
      add_column :distributors, :investor_id, :integer
      add_index :distributors, :investor_id
    end
  end
end
