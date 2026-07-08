class AddLeadIdToOtherInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :other_insurances, :lead_id, :string unless column_exists?(:other_insurances, :lead_id)
    add_index :other_insurances, :lead_id unless index_exists?(:other_insurances, :lead_id)
  end
end
