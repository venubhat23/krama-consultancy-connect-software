class AddOriginalPolicyIdToHealthInsurances < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:health_insurances, :original_policy_id)
      add_column :health_insurances, :original_policy_id, :bigint
      add_foreign_key :health_insurances, :health_insurances,
                      column: :original_policy_id,
                      name: "health_insurances_original_policy_id_fkey"
    end
  end
end
