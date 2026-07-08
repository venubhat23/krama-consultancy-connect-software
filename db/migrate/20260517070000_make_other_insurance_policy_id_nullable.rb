class MakeOtherInsurancePolicyIdNullable < ActiveRecord::Migration[8.0]
  def up
    change_column_null :other_insurances, :policy_id, true
  end

  def down
    change_column_null :other_insurances, :policy_id, false
  end
end
