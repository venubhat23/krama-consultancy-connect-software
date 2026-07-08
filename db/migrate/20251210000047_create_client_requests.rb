class CreateClientRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :client_requests do |t|
      t.string :ticket_number, null: false
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone_number, null: false
      t.text :description, null: false
      t.string :status, default: 'pending'
      t.string :priority, default: 'medium'
      t.datetime :submitted_at, null: false
      t.text :admin_response
      t.datetime :resolved_at
      t.references :resolved_by, foreign_key: { to_table: :users }, null: true

      t.timestamps
    end

    add_index :client_requests, :ticket_number, unique: true
    add_index :client_requests, :email
    add_index :client_requests, :status
    add_index :client_requests, :submitted_at
  end
end
