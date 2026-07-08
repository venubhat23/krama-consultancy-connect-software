class AddFundToLifeInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :life_insurances, :fund, :decimal unless column_exists?(:life_insurances, :fund)
  end
end
