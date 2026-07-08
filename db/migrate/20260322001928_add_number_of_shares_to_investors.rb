class AddNumberOfSharesToInvestors < ActiveRecord::Migration[8.0]
  def change
    add_column :investors, :number_of_shares, :integer
  end
end
