class AddDistributorIdToOtherInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :other_insurances, :distributor_id, :integer unless column_exists?(:other_insurances, :distributor_id)
  end
end
