class RemovePasswordDigestFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :password_digest, :string if column_exists?(:users, :password_digest)
  end
end
