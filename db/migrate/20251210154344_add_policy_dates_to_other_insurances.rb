class AddPolicyDatesToOtherInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :other_insurances, :policy_end_date, :date
    add_column :other_insurances, :policy_start_date, :date
    add_column :other_insurances, :policy_booking_date, :date
  end
end
