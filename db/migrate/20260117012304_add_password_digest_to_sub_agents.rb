class AddPasswordDigestToSubAgents < ActiveRecord::Migration[8.0]
  def change
    add_column :sub_agents, :password_digest, :string unless column_exists?(:sub_agents, :password_digest)
  end
end
