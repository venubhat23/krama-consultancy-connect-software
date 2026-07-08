class UpdateFamilyMembersStructure < ActiveRecord::Migration[8.0]
  def change
    rename_column :family_members, :name, :first_name
    add_column :family_members, :middle_name, :string
    add_column :family_members, :last_name, :string
    add_column :family_members, :height_feet, :string
    add_column :family_members, :weight_kg, :decimal, precision: 5, scale: 2
    add_column :family_members, :additional_information, :text
    rename_column :family_members, :pan_number, :pan_no
  end
end
