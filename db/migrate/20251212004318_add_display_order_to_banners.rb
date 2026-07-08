class AddDisplayOrderToBanners < ActiveRecord::Migration[8.0]
  def change
    add_column :banners, :display_order, :integer, default: 0
    add_index :banners, :display_order
  end
end
