class AddInvoicedToDistributorPayouts < ActiveRecord::Migration[8.0]
  def change
    add_column :distributor_payouts, :invoiced, :boolean, default: false
  end
end
