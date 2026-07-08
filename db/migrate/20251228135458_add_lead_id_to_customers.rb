class AddLeadIdToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :lead_id, :string
    add_index :customers, :lead_id, unique: true
  end
end
