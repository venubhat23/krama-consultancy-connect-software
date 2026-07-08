class AddPremiumFrequencyToHealthInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :health_insurances, :premium_frequency, :string, limit: 50 unless column_exists?(:health_insurances, :premium_frequency)
  end
end
