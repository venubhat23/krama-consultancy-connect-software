class AddProductThroughDrToInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :health_insurances, :product_through_dr, :boolean, default: false
    add_column :life_insurances, :product_through_dr, :boolean, default: false
    add_column :motor_insurances, :product_through_dr, :boolean, default: false
    add_column :other_insurances, :product_through_dr, :boolean, default: false
  end
end
