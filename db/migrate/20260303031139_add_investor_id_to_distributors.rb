class AddInvestorIdToDistributors < ActiveRecord::Migration[8.0]
  def change
    add_column :distributors, :investor_id, :integer
    add_index :distributors, :investor_id
  end
end
