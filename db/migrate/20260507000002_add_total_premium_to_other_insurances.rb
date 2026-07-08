class AddTotalPremiumToOtherInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :other_insurances, :total_premium, :decimal, precision: 15, scale: 2, default: 0.0 unless column_exists?(:other_insurances, :total_premium)
    add_column :other_insurances, :net_premium, :decimal, precision: 15, scale: 2, default: 0.0 unless column_exists?(:other_insurances, :net_premium)
  end
end
