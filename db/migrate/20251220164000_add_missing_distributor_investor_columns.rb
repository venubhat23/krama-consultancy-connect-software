class AddMissingDistributorInvestorColumns < ActiveRecord::Migration[8.0]
  def change
    # Add missing columns to health_insurances
    unless column_exists?(:health_insurances, :distributor_id)
      add_reference :health_insurances, :distributor, null: true, foreign_key: true
    end

    unless column_exists?(:health_insurances, :investor_id)
      add_reference :health_insurances, :investor, null: true, foreign_key: true
    end

    # Add missing columns to motor_insurances
    unless column_exists?(:motor_insurances, :investor_id)
      add_reference :motor_insurances, :investor, null: true, foreign_key: true
    end

    # Add missing columns to other_insurances
    unless column_exists?(:other_insurances, :distributor_id)
      add_reference :other_insurances, :distributor, null: true, foreign_key: true
    end

    unless column_exists?(:other_insurances, :investor_id)
      add_reference :other_insurances, :investor, null: true, foreign_key: true
    end
  end
end