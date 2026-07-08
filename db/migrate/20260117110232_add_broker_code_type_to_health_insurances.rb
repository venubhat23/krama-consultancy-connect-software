class AddBrokerCodeTypeToHealthInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :health_insurances, :broker_code_type, :string
  end
end
