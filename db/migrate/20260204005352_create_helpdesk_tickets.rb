class CreateHelpdeskTickets < ActiveRecord::Migration[8.0]
  def change
    create_table :helpdesk_tickets do |t|
      t.string :ticket_number
      t.string :subject
      t.text :description
      t.string :status
      t.string :priority
      t.string :category
      t.string :submitter_type
      t.integer :submitter_id
      t.integer :assigned_to
      t.text :resolution_notes
      t.datetime :resolved_at
      t.references :sub_agent, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true

      t.timestamps
    end
    add_index :helpdesk_tickets, :ticket_number, unique: true
  end
end
