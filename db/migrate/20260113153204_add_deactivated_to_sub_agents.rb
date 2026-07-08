class AddDeactivatedToSubAgents < ActiveRecord::Migration[8.0]
  def change
    add_column :sub_agents, :deactivated, :boolean, default: false
  end
end
