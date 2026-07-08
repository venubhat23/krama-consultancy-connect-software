class FixProductThroughDrDefault < ActiveRecord::Migration[8.0]
  def up
    change_column_default :health_insurances, :product_through_dr, from: false, to: true
    change_column_default :life_insurances, :product_through_dr, from: nil, to: true

    execute "UPDATE health_insurances SET product_through_dr = TRUE WHERE product_through_dr = FALSE OR product_through_dr IS NULL"
    execute "UPDATE life_insurances SET product_through_dr = TRUE WHERE product_through_dr = FALSE OR product_through_dr IS NULL"
  end

  def down
    change_column_default :health_insurances, :product_through_dr, from: true, to: false
    change_column_default :life_insurances, :product_through_dr, from: true, to: nil
  end
end
