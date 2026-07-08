class AddLeadIdToCommissionPayouts < ActiveRecord::Migration[8.0]
  def change
    add_column :commission_payouts, :lead_id, :string
    add_index :commission_payouts, :lead_id
  end
end
