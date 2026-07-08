class AddPolicyNumberToOtherInsurances < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:other_insurances, :policy_number)
      add_column :other_insurances, :policy_number, :string, limit: 255
    end
  end
end
