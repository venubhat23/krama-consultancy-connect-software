class MergeCompanyNameAndType < ActiveRecord::Migration[8.0]
  def up
    # Since we've already cleared all data, we can safely remove the insurance_type column
    remove_column :insurance_companies, :insurance_type, :string
  end

  def down
    # Add back the insurance_type column if we need to rollback
    add_column :insurance_companies, :insurance_type, :string
  end
end
