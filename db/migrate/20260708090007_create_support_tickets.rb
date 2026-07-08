class CreateSupportTickets < ActiveRecord::Migration[8.0]
  def change
    create_table :support_tickets do |t|
      t.references :forum, foreign_key: true
      t.references :chapter, foreign_key: true
      t.references :raised_by, null: false, foreign_key: { to_table: :users }
      t.string :subject, null: false
      t.text :body, null: false
      t.integer :status, default: 0, null: false
      t.integer :priority, default: 1, null: false

      t.timestamps
    end
    add_index :support_tickets, :status

    create_table :support_ticket_replies do |t|
      t.references :support_ticket, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false

      t.timestamps
    end
  end
end
