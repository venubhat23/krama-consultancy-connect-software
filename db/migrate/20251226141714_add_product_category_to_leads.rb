class AddProductCategoryToLeads < ActiveRecord::Migration[8.0]
  def change
    add_column :leads, :product_category, :string
    add_column :leads, :product_subcategory, :string
  end
end
