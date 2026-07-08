class AddPolicyHolderToPolicies < ActiveRecord::Migration[8.0]
  def change
    add_column :policies, :policy_holder, :string
  end
end
