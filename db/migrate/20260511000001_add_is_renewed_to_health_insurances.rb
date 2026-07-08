class AddIsRenewedToHealthInsurances < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:health_insurances, :is_renewed)
      add_column :health_insurances, :is_renewed, :boolean, default: false
    end
  end
end
