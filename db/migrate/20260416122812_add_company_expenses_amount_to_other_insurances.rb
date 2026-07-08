class AddCompanyExpensesAmountToOtherInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :other_insurances, :company_expenses_amount, :decimal
  end
end
