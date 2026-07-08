class AddCommissionDetailsToMotorInsurances < ActiveRecord::Migration[8.0]
  def change
    # Sub Agent Commission
    add_column :motor_insurances, :sub_agent_commission_percentage, :decimal, precision: 8, scale: 2
    add_column :motor_insurances, :sub_agent_commission_amount, :decimal, precision: 12, scale: 2
    add_column :motor_insurances, :sub_agent_tds_percentage, :decimal, precision: 8, scale: 2
    add_column :motor_insurances, :sub_agent_tds_amount, :decimal, precision: 12, scale: 2
    add_column :motor_insurances, :sub_agent_after_tds_value, :decimal, precision: 12, scale: 2

    # Distributor Commission (Affiliate)
    add_column :motor_insurances, :distributor_commission_percentage, :decimal, precision: 8, scale: 2
    add_column :motor_insurances, :distributor_commission_amount, :decimal, precision: 12, scale: 2
    add_column :motor_insurances, :distributor_tds_percentage, :decimal, precision: 8, scale: 2
    add_column :motor_insurances, :distributor_tds_amount, :decimal, precision: 12, scale: 2
    add_column :motor_insurances, :distributor_after_tds_value, :decimal, precision: 12, scale: 2

    # Investor Commission
    add_column :motor_insurances, :investor_commission_percentage, :decimal, precision: 8, scale: 2
    add_column :motor_insurances, :investor_commission_amount, :decimal, precision: 12, scale: 2
    add_column :motor_insurances, :investor_tds_percentage, :decimal, precision: 8, scale: 2
    add_column :motor_insurances, :investor_tds_amount, :decimal, precision: 12, scale: 2
    add_column :motor_insurances, :investor_after_tds_value, :decimal, precision: 12, scale: 2

    # Ambassador Commission
    add_column :motor_insurances, :ambassador_commission_percentage, :decimal, precision: 8, scale: 2
    add_column :motor_insurances, :ambassador_commission_amount, :decimal, precision: 12, scale: 2
    add_column :motor_insurances, :ambassador_tds_percentage, :decimal, precision: 8, scale: 2
    add_column :motor_insurances, :ambassador_tds_amount, :decimal, precision: 12, scale: 2
    add_column :motor_insurances, :ambassador_after_tds_value, :decimal, precision: 12, scale: 2

    # Company calculations
    add_column :motor_insurances, :total_distribution_percentage, :decimal, precision: 8, scale: 2
    add_column :motor_insurances, :company_expenses_percentage, :decimal, precision: 8, scale: 2
    add_column :motor_insurances, :profit_percentage, :decimal, precision: 8, scale: 2
    add_column :motor_insurances, :profit_amount, :decimal, precision: 12, scale: 2

    # Main agent fields (to match life insurance structure)
    add_column :motor_insurances, :commission_amount, :decimal, precision: 12, scale: 2
    add_column :motor_insurances, :tds_percentage, :decimal, precision: 8, scale: 2
    add_column :motor_insurances, :tds_amount, :decimal, precision: 12, scale: 2
    add_column :motor_insurances, :main_agent_commission_percentage, :decimal, precision: 8, scale: 2
  end
end
