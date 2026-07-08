class AddDeactivatedToDistributors < ActiveRecord::Migration[8.0]
  def change
    add_column :distributors, :deactivated, :boolean, default: false
  end
end
