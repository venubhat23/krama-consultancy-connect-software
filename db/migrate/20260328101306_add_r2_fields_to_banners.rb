class AddR2FieldsToBanners < ActiveRecord::Migration[8.0]
  def change
    add_column :banners, :r2_file_key, :string
    add_column :banners, :r2_filename, :string
    add_column :banners, :r2_content_type, :string
    add_column :banners, :r2_file_size, :bigint
    add_column :banners, :r2_public_url, :text
  end
end
