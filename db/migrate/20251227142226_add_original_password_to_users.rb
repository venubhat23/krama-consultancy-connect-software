class AddOriginalPasswordToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :original_password, :string
  end
end
