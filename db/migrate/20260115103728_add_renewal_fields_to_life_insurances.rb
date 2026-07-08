class AddRenewalFieldsToLifeInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :life_insurances, :original_policy_id, :integer, null: true
    add_column :life_insurances, :renewal_policy_id, :integer, null: true
    add_column :life_insurances, :is_renewed, :boolean, default: false, null: false

    # Add indexes for better query performance
    add_index :life_insurances, :original_policy_id
    add_index :life_insurances, :renewal_policy_id
    add_index :life_insurances, :is_renewed
  end
end
