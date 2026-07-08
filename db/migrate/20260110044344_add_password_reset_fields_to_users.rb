class AddPasswordResetFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :password_reset_at, :datetime, comment: 'When password was last reset'
  end
end
