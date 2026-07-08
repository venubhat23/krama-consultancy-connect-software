class AddPolicyTypeToOtherInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :other_insurances, :policy_type, :string
  end
end
