class AddParentLeadIdToLeads < ActiveRecord::Migration[8.0]
  def change
    add_column :leads, :parent_lead_id, :integer unless column_exists?(:leads, :parent_lead_id)
    add_index :leads, :parent_lead_id, if_not_exists: true
  end
end
