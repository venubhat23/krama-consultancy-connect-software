class AddSubAgentIdToOtherInsurances < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:other_insurances, :sub_agent_id)
      add_column :other_insurances, :sub_agent_id, :integer
    end
  end
end
