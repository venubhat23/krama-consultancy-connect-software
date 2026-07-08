class CreateBanners < ActiveRecord::Migration[8.0]
  def change
    create_table :banners do |t|
      t.string :title
      t.string :description
      t.string :redirect_link
      t.date :display_start_date
      t.date :display_end_date
      t.string :display_location
      t.boolean :status

      t.timestamps
    end
  end
end
