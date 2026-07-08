class AddMainIncomeAndDistributorCommissionToLifeInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :life_insurances, :main_income_percentage, :decimal unless column_exists?(:life_insurances, :main_income_percentage)
    add_column :life_insurances, :main_income_amount, :decimal unless column_exists?(:life_insurances, :main_income_amount)
    add_column :life_insurances, :distributor_commission_percentage, :decimal unless column_exists?(:life_insurances, :distributor_commission_percentage)
    add_column :life_insurances, :distributor_commission_amount, :decimal unless column_exists?(:life_insurances, :distributor_commission_amount)
    add_column :life_insurances, :distributor_tds_percentage, :decimal unless column_exists?(:life_insurances, :distributor_tds_percentage)
    add_column :life_insurances, :distributor_tds_amount, :decimal unless column_exists?(:life_insurances, :distributor_tds_amount)
    add_column :life_insurances, :distributor_after_tds_value, :decimal unless column_exists?(:life_insurances, :distributor_after_tds_value)
  end
end
