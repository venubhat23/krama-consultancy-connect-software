class AddBrokerToAgencyCodes < ActiveRecord::Migration[8.0]
  def change
    add_reference :agency_codes, :broker, null: true, foreign_key: true
  end
end
