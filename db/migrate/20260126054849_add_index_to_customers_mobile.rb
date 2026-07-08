class AddIndexToCustomersMobile < ActiveRecord::Migration[8.0]
  def change
    add_index :customers, :mobile unless index_exists?(:customers, :mobile)
  end
end
