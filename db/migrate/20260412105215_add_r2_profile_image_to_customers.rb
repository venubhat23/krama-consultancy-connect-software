class AddR2ProfileImageToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :r2_profile_image_key, :string
    add_column :customers, :r2_profile_image_filename, :string
    add_column :customers, :r2_profile_image_content_type, :string
    add_column :customers, :r2_profile_image_size, :bigint
    add_column :customers, :r2_profile_image_public_url, :text
  end
end
