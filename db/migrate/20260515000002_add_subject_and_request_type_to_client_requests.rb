class AddSubjectAndRequestTypeToClientRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :client_requests, :subject, :string unless column_exists?(:client_requests, :subject)
    add_column :client_requests, :request_type, :string unless column_exists?(:client_requests, :request_type)
  end
end
