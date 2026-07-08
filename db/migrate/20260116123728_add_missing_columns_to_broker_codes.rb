class AddMissingColumnsToBrokerCodes < ActiveRecord::Migration[8.0]
  def change
    add_column :broker_codes, :agent_name, :string
  end
end
