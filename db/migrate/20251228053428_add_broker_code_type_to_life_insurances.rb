class AddBrokerCodeTypeToLifeInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :life_insurances, :broker_code_type, :string
  end
end
