class AddPasswordFieldsToInvestors < ActiveRecord::Migration[8.0]
  def change
    add_column :investors, :password_digest, :string
    add_column :investors, :username, :string
    add_column :investors, :original_password, :string
  end
end
