class AddPolicyIdToOtherInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :other_insurances, :policy_id, :integer unless column_exists?(:other_insurances, :policy_id)
    add_index :other_insurances, :policy_id unless index_exists?(:other_insurances, :policy_id)
    add_foreign_key :other_insurances, :policies unless foreign_key_exists?(:other_insurances, :policies)
  end
end
