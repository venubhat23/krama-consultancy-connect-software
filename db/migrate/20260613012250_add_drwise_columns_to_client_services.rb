class AddDrwiseColumnsToClientServices < ActiveRecord::Migration[8.0]
  def change
    add_column :client_services, :is_admin_added,    :boolean, default: false, null: false
    add_column :client_services, :is_customer_added, :boolean, default: true,  null: false
    add_column :client_services, :is_agent_added,    :boolean, default: false, null: false
  end
end
