class AddAmbassadorCommissionToLifeInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :life_insurances, :ambassador_commission_percentage, :decimal
    add_column :life_insurances, :ambassador_commission_amount, :decimal
    add_column :life_insurances, :ambassador_tds_percentage, :decimal
    add_column :life_insurances, :ambassador_tds_amount, :decimal
    add_column :life_insurances, :ambassador_after_tds_value, :decimal
  end
end
