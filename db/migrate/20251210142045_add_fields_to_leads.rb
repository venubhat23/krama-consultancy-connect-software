class AddFieldsToLeads < ActiveRecord::Migration[8.0]
  def change
    add_column :leads, :lead_id, :string
    add_column :leads, :address, :text
    add_column :leads, :city, :string
    add_column :leads, :state, :string
    add_column :leads, :lead_source, :string
    add_column :leads, :call_disposition, :string
    add_column :leads, :referral_amount, :decimal, precision: 10, scale: 2, default: 0.0
    add_column :leads, :transferred_amount, :boolean, default: false
    add_column :leads, :notes, :text
    add_column :leads, :attachments, :text
    add_column :leads, :stage_updated_at, :datetime
    add_column :leads, :converted_customer_id, :integer
    add_column :leads, :policy_created_id, :integer

    add_index :leads, :lead_id, unique: true
    add_index :leads, :current_stage
    add_index :leads, :lead_source
    add_index :leads, :converted_customer_id
    add_index :leads, :policy_created_id
  end
end
