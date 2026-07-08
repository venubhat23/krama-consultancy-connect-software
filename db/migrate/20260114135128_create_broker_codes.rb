class CreateBrokerCodes < ActiveRecord::Migration[8.0]
  def change
    create_table :broker_codes do |t|
      t.references :broker, null: false, foreign_key: true
      t.string :agent_name
      t.string :broker_code
      t.string :company_name
      t.boolean :status

      t.timestamps
    end
  end
end
