class AddIndexesToCustomersForPerformance < ActiveRecord::Migration[8.0]
  def change
    # Add indexes for commonly queried fields
    add_index :customers, :customer_type
    add_index :customers, :status
    add_index :customers, [:customer_type, :status]
    add_index :customers, :created_at
    add_index :customers, :email
    add_index :customers, :mobile
    add_index :customers, :pan_number

    # Add composite indexes for search and filtering
    add_index :customers, [:status, :created_at]
    add_index :customers, [:customer_type, :created_at]

    # Add indexes for policies table if not already present
    add_index :policies, :customer_id unless index_exists?(:policies, :customer_id)
    add_index :policies, [:customer_id, :created_at] unless index_exists?(:policies, [:customer_id, :created_at])
  end
end
