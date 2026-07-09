class AddBusinessProfileFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :business_category, :string unless column_exists?(:users, :business_category)
    add_column :users, :speciality, :string unless column_exists?(:users, :speciality)
    add_column :users, :nature_of_business, :string unless column_exists?(:users, :nature_of_business)
    add_column :users, :website, :string unless column_exists?(:users, :website)
  end
end
