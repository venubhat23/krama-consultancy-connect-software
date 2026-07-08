class AddIndexesToLeadsForPerformance < ActiveRecord::Migration[8.0]
  def change
    # Add indexes for common search and filter fields
    add_index :leads, :contact_number, if_not_exists: true
    add_index :leads, :email, if_not_exists: true
    add_index :leads, :current_stage, if_not_exists: true
    add_index :leads, :lead_source, if_not_exists: true
    add_index :leads, :product_category, if_not_exists: true
    add_index :leads, :product_subcategory, if_not_exists: true
    add_index :leads, :converted_customer_id, if_not_exists: true
    add_index :leads, :company_name, if_not_exists: true
    add_index :leads, :lead_id, if_not_exists: true
    add_index :leads, :affiliate_id, if_not_exists: true
    add_index :leads, :is_direct, if_not_exists: true

    # Composite indexes for common query patterns
    add_index :leads, [:first_name, :last_name], if_not_exists: true
    add_index :leads, [:product_category, :product_subcategory], if_not_exists: true
    add_index :leads, [:current_stage, :created_at], if_not_exists: true
  end
end
