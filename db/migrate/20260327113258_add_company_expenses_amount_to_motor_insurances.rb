class AddCompanyExpensesAmountToMotorInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :motor_insurances, :company_expenses_amount, :decimal
  end
end
