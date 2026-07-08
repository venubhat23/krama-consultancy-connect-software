class AddPoliciesCountToCustomers < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:customers, :policies_count)
      add_column :customers, :policies_count, :integer, default: 0, null: false
    end
  end
end
