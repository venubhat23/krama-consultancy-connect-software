class AddAffiliateCountToDistributors < ActiveRecord::Migration[8.0]
  def change
    add_column :distributors, :affiliate_count, :integer, default: 0, null: false

    # Update existing records with current count
    reversible do |dir|
      dir.up do
        Distributor.reset_column_information
        Distributor.find_each do |distributor|
          distributor.update_column(:affiliate_count, distributor.assigned_sub_agents.count)
        end
      end
    end
  end
end
