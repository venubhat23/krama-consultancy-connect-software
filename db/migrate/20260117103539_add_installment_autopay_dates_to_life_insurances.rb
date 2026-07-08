class AddInstallmentAutopayDatesToLifeInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :life_insurances, :installment_autopay_start_date, :date unless column_exists?(:life_insurances, :installment_autopay_start_date)
    add_column :life_insurances, :installment_autopay_end_date, :date unless column_exists?(:life_insurances, :installment_autopay_end_date)
  end
end
