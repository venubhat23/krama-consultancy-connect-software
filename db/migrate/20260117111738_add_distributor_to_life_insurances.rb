class AddDistributorToLifeInsurances < ActiveRecord::Migration[8.0]
  def change
    add_reference :life_insurances, :distributor, null: true, foreign_key: true unless column_exists?(:life_insurances, :distributor_id)
  end
end
