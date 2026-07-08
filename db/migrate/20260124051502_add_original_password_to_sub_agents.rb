class AddOriginalPasswordToSubAgents < ActiveRecord::Migration[8.0]
  def change
    add_column :sub_agents, :original_password, :string unless column_exists?(:sub_agents, :original_password)
  end
end
