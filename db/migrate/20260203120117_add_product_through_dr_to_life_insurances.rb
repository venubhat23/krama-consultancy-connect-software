class AddProductThroughDrToLifeInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :life_insurances, :product_through_dr, :boolean unless column_exists?(:life_insurances, :product_through_dr)
  end
end
