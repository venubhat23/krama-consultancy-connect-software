class AddPasswordResetAtToSubAgents < ActiveRecord::Migration[8.0]
  def change
    add_column :sub_agents, :password_reset_at, :datetime
  end
end
