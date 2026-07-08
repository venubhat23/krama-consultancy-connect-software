class AddForumFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_reference :users, :forum, foreign_key: true, null: true
    add_reference :users, :chapter, foreign_key: true, null: true
    add_column :users, :session_token, :string
    add_index :users, :session_token, unique: true

    reversible do |dir|
      dir.up do
        execute "UPDATE users SET session_token = md5(random()::text || clock_timestamp()::text) WHERE session_token IS NULL"
      end
    end

    change_column_null :users, :session_token, false
  end
end
