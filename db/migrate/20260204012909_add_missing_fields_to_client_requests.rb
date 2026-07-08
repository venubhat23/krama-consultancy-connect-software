class AddMissingFieldsToClientRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :client_requests, :category, :string
    add_column :client_requests, :submitter_type, :string
    add_column :client_requests, :submitter_id, :integer
    add_index :client_requests, [:submitter_type, :submitter_id]
  end
end
