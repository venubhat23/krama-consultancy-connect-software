class CreateBrokers < ActiveRecord::Migration[8.0]
  def change
    create_table :brokers do |t|
      t.string :name, null: false
      t.string :status, default: 'active'

      t.timestamps
    end

    add_index :brokers, :name
    add_index :brokers, :status
  end
end
