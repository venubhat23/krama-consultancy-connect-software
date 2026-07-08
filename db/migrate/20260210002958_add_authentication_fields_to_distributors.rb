class AddAuthenticationFieldsToDistributors < ActiveRecord::Migration[8.0]
  def change
    add_column :distributors, :username, :string
    add_column :distributors, :password_digest, :string
    add_column :distributors, :original_password, :string
  end
end
