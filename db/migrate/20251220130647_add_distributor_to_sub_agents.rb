class AddDistributorToSubAgents < ActiveRecord::Migration[8.0]
  def change
    add_reference :sub_agents, :distributor, null: true, foreign_key: true
  end
end
