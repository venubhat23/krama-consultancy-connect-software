class AddNomineeDobToHealthInsurances < ActiveRecord::Migration[8.0]
  def change
    add_column :health_insurances, :nominee_dob, :date
  end
end
