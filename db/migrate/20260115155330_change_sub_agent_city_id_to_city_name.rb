class ChangeSubAgentCityIdToCityName < ActiveRecord::Migration[8.0]
  def up
    # Add new city column as string
    add_column :sub_agents, :city, :string
    add_column :distributors, :city, :string

    # Add new state column as string for consistency
    add_column :sub_agents, :state, :string
    add_column :distributors, :state, :string
  end

  def down
    # Remove the new columns
    remove_column :sub_agents, :city, :string
    remove_column :distributors, :city, :string
    remove_column :sub_agents, :state, :string
    remove_column :distributors, :state, :string
  end
end
