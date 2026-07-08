class CreateAgencyBrokers < ActiveRecord::Migration[8.0]
  def change
    create_table :agency_brokers do |t|
      t.string :broker_name
      t.string :broker_code
      t.string :agency_code
      t.boolean :status

      t.timestamps
    end
  end
end
