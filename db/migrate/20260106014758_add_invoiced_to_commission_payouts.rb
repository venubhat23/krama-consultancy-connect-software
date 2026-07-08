class AddInvoicedToCommissionPayouts < ActiveRecord::Migration[8.0]
  def change
    add_column :commission_payouts, :invoiced, :boolean, default: false
  end
end
