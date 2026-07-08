class AddDirectReferredFieldsToLeads < ActiveRecord::Migration[8.0]
  def change
    add_column :leads, :is_direct, :boolean, default: true
    add_column :leads, :affiliate_id, :integer
    add_index :leads, :affiliate_id
  end
end
