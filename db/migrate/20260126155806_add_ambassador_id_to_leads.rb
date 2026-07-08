class AddAmbassadorIdToLeads < ActiveRecord::Migration[8.0]
  def change
    add_column :leads, :ambassador_id, :integer
    add_index :leads, :ambassador_id

    # Add foreign key constraint (ambassador is actually distributor)
    add_foreign_key :leads, :distributors, column: :ambassador_id
  end
end
