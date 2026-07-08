class AddAgencyCodeToBrokerCodes < ActiveRecord::Migration[8.0]
  def change
    add_reference :broker_codes, :agency_code, null: true, foreign_key: true
  end
end
