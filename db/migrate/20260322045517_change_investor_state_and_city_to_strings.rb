class ChangeInvestorStateAndCityToStrings < ActiveRecord::Migration[8.0]
  def change
    # Change state_id from integer to string and rename to state
    change_column :investors, :state_id, :string
    rename_column :investors, :state_id, :state

    # Change city_id from integer to string and rename to city
    change_column :investors, :city_id, :string
    rename_column :investors, :city_id, :city
  end
end
