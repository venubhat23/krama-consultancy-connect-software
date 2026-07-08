class RemoveAgencyCodeAndAgentNameFromBrokerCodes < ActiveRecord::Migration[8.0]
  def change
    remove_reference :broker_codes, :agency_code, null: true, foreign_key: true
    remove_column :broker_codes, :agent_name, :string
  end
end
