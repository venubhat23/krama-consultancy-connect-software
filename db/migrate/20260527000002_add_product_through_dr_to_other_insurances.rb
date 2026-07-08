class AddProductThroughDrToOtherInsurances < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:other_insurances, :product_through_dr)
      add_column :other_insurances, :product_through_dr, :boolean, default: true
    end
  end
end
