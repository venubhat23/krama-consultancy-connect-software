class AddBonusToLifeInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :life_insurances, :bonus, :decimal unless column_exists?(:life_insurances, :bonus)
  end
end
