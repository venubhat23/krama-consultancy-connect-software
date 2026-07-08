class AddIsBranchOutToLeads < ActiveRecord::Migration[8.0]
  def change
    add_column :leads, :is_branch_out, :boolean, default: false
  end
end
