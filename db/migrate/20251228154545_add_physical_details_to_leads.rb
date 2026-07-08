class AddPhysicalDetailsToLeads < ActiveRecord::Migration[8.0]
  def change
    add_column :leads, :height, :string
    add_column :leads, :weight, :string
    add_column :leads, :birth_place, :string
  end
end
