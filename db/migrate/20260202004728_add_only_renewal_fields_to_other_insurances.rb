class AddOnlyRenewalFieldsToOtherInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :other_insurances, :is_renewed, :boolean
    add_column :other_insurances, :original_policy_id, :integer
  end
end
