class AddPaidAtToInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :paid_at, :datetime unless column_exists?(:invoices, :paid_at)
  end
end
