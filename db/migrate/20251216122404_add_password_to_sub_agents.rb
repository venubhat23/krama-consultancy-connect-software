class AddPasswordToSubAgents < ActiveRecord::Migration[8.0]
  def change
    add_column :sub_agents, :password_digest, :string
  end
end
