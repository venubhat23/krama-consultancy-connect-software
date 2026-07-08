class SafelyAddDistributorInvestorToInsurances < ActiveRecord::Migration[8.0]
  def change
    # Add distributor and investor references to health_insurances if they don't exist
    unless column_exists?(:health_insurances, :distributor_id)
      add_reference :health_insurances, :distributor, null: true, foreign_key: true
    end

    unless column_exists?(:health_insurances, :investor_id)
      add_reference :health_insurances, :investor, null: true, foreign_key: true
    end

    # Add distributor reference to motor_insurances if it doesn't exist
    unless column_exists?(:motor_insurances, :distributor_id)
      add_reference :motor_insurances, :distributor, null: true, foreign_key: true
    end

    # Add investor reference to motor_insurances if it doesn't exist
    unless column_exists?(:motor_insurances, :investor_id)
      add_reference :motor_insurances, :investor, null: true, foreign_key: true
    end

    # Add distributor reference to other_insurances if it doesn't exist
    unless column_exists?(:other_insurances, :distributor_id)
      add_reference :other_insurances, :distributor, null: true, foreign_key: true
    end

    # Add investor reference to other_insurances if it doesn't exist
    unless column_exists?(:other_insurances, :investor_id)
      add_reference :other_insurances, :investor, null: true, foreign_key: true
    end
  end
end
